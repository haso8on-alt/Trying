//+------------------------------------------------------------------+
//|                              Finally_fucked.mq5                   |
//|                    Professional XAUUSD H1 Expert Advisor         |
//|    MACD + 200EMA + RSI + ADX + Vol Filter + Break-Even Trail     |
//|                            v5.00                                  |
//+------------------------------------------------------------------+
//
//  KEY UPGRADES vs v4:
//  1. Break-Even Stop: once profit >= InpBEATR × ATR, SL moves to
//     entry price + small buffer. This eliminates full-loss exits on
//     trades that were in profit, turning them into zero-loss exits.
//
//  2. Delayed Trailing: trailing stop only activates after profit
//     reaches InpTrailActivateATR × ATR. Before that, only break-even
//     logic runs. This gives winning trades room to grow before the
//     trail tightens — fixing the "small wins vs large losses" problem.
//
//  Root cause fixed: v3/v4 had PF ~1.1 despite 71% win rate because
//  trailing was closing winners at tiny profits while losers hit full SL.
//
//+------------------------------------------------------------------+
#property copyright   "GoldPro EA v5.00"
#property version     "5.00"
#property description "XAUUSD H1 — MACD+200EMA+RSI+ADX+VolFilter+BreakEven+DelayedTrail"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//==========================================================================
//  INPUTS
//==========================================================================

input group "─── Strategy ───────────────────────────────"
input int    InpMACDFast      = 12;    // MACD Fast EMA Period
input int    InpMACDSlow      = 26;    // MACD Slow EMA Period
input int    InpMACDSignal    = 9;     // MACD Signal Period
input int    InpTrendEMA      = 200;   // Trend Filter EMA Period
input int    InpRSIPeriod     = 14;    // RSI Period
input double InpRSIOverbought = 70.0;  // RSI Overbought Level
input double InpRSIOversold   = 30.0;  // RSI Oversold Level
input int    InpADXPeriod     = 14;    // ADX Period
input double InpADXMinLevel   = 20.0;  // ADX Minimum (skip choppy markets)
input int    InpATRPeriod     = 14;    // ATR Period

input group "─── Volatility Filter ───────────────────────"
input int    InpVolATRPeriod  = 50;    // ATR Average Period
input double InpVolATRMult    = 1.1;   // Vol Threshold: ATR > AvgATR × this

input group "─── Risk Management ────────────────────────"
input double InpRiskPercent    = 0.7;  // Risk Per Trade (% of Balance)
input double InpATRMultSL      = 2.0;  // ATR Multiplier for Stop Loss
input double InpRiskReward     = 2.0;  // Risk:Reward Ratio (1 : X)
input double InpMinBalance     = 500.0;// Minimum Balance Required ($)
input double InpMaxLotRiskMult = 2.0;  // Skip if min-lot risk > X × target risk
input double InpMaxDailyDD     = 3.0;  // Max Daily Drawdown (%) — halt if hit

input group "─── Break-Even & Trailing ───────────────────"
input double InpBEATR          = 1.0;  // Break-Even: activate when profit >= X × ATR
//                                     // 1.0 = SL moves to entry once +1 ATR profit
input double InpBEBuffer       = 0.1;  // Break-Even buffer above entry (× ATR)
//                                     // 0.1 = SL = entry + 0.1×ATR (small profit lock)
input double InpTrailActivate  = 1.5;  // Trailing: activate when profit >= X × ATR
//                                     // 1.5 = trail only starts after +1.5 ATR profit
input double InpTrailATRMult   = 1.0;  // Trailing distance (× ATR) once activated

input group "─── Session Filter ──────────────────────────"
input bool   InpUseSession    = true;  // Enable Session Filter
input int    InpSessionStart  = 8;     // Session Start Hour (Server UTC)
input int    InpSessionEnd    = 22;    // Session End Hour   (Server UTC)

input group "─── Trade Settings ─────────────────────────"
input int    InpMagicNumber   = 20240101;     // Magic Number
input int    InpSlippage      = 15;           // Max Slippage (points)
input string InpComment       = "GoldPro_H1"; // Trade Comment

//==========================================================================
//  GLOBALS
//==========================================================================

CTrade        g_trade;
CPositionInfo g_pos;
CAccountInfo  g_acct;

int g_hMACD     = INVALID_HANDLE;
int g_hTrendEMA = INVALID_HANDLE;
int g_hRSI      = INVALID_HANDLE;
int g_hADX      = INVALID_HANDLE;
int g_hATR      = INVALID_HANDLE;

double g_bufMACD[];
double g_bufSignal[];
double g_bufTrendEMA[];
double g_bufRSI[];
double g_bufADX[];
double g_bufATR[];

datetime g_lastBarTime  = 0;
double   g_dayStartBal  = 0.0;
datetime g_lastDayReset = 0;

//==========================================================================
//  OnInit
//==========================================================================
int OnInit()
{
   if(InpMACDFast >= InpMACDSlow)
   { Print("ERROR: MACDFast must be < MACDSlow"); return INIT_PARAMETERS_INCORRECT; }
   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
   { Print("ERROR: RiskPercent must be 0.01–10"); return INIT_PARAMETERS_INCORRECT; }
   if(InpRiskReward < 1.0)
   { Print("ERROR: RiskReward must be >= 1.0"); return INIT_PARAMETERS_INCORRECT; }
   if(InpTrailActivate < InpBEATR)
   { Print("ERROR: TrailActivate must be >= BEATR (trail starts after break-even)"); return INIT_PARAMETERS_INCORRECT; }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(DetectFillingMode());
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   g_hMACD     = iMACD(_Symbol, PERIOD_H1, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hTrendEMA = iMA  (_Symbol, PERIOD_H1, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI (_Symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);
   g_hADX      = iADX (_Symbol, PERIOD_H1, InpADXPeriod);
   g_hATR      = iATR (_Symbol, PERIOD_H1, InpATRPeriod);

   if(g_hMACD == INVALID_HANDLE || g_hTrendEMA == INVALID_HANDLE ||
      g_hRSI  == INVALID_HANDLE || g_hADX      == INVALID_HANDLE ||
      g_hATR  == INVALID_HANDLE)
   { Print("ERROR: Failed to create indicator handles!"); return INIT_FAILED; }

   ArraySetAsSeries(g_bufMACD,     true);
   ArraySetAsSeries(g_bufSignal,   true);
   ArraySetAsSeries(g_bufTrendEMA, true);
   ArraySetAsSeries(g_bufRSI,      true);
   ArraySetAsSeries(g_bufADX,      true);
   ArraySetAsSeries(g_bufATR,      true);

   g_dayStartBal  = g_acct.Balance();
   g_lastDayReset = TimeCurrent();

   PrintFormat("══════════════════════════════════════════════════");
   PrintFormat("  GoldPro H1 EA v5.00 — Initialized");
   PrintFormat("  Symbol  : %s  |  Timeframe : H1", _Symbol);
   PrintFormat("  MACD    : %d/%d/%d  |  TrendEMA: %d",
               InpMACDFast, InpMACDSlow, InpMACDSignal, InpTrendEMA);
   PrintFormat("  VolFilt : ATR > AvgATR(%d) × %.1f", InpVolATRPeriod, InpVolATRMult);
   PrintFormat("  BE      : activates at +%.1f×ATR → SL = entry + %.1f×ATR",
               InpBEATR, InpBEBuffer);
   PrintFormat("  Trail   : activates at +%.1f×ATR | distance %.1f×ATR",
               InpTrailActivate, InpTrailATRMult);
   PrintFormat("  Risk    : %.1f%%  |  RR: 1:%.1f  |  SL: %.1f×ATR",
               InpRiskPercent, InpRiskReward, InpATRMultSL);
   PrintFormat("  DailyDD : %.1f%%  |  Session: %02d:00–%02d:00",
               InpMaxDailyDD, InpSessionStart, InpSessionEnd);
   PrintFormat("══════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//==========================================================================
//  OnDeinit
//==========================================================================
void OnDeinit(const int reason)
{
   if(g_hMACD     != INVALID_HANDLE) IndicatorRelease(g_hMACD);
   if(g_hTrendEMA != INVALID_HANDLE) IndicatorRelease(g_hTrendEMA);
   if(g_hRSI      != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   if(g_hADX      != INVALID_HANDLE) IndicatorRelease(g_hADX);
   if(g_hATR      != INVALID_HANDLE) IndicatorRelease(g_hATR);
   Comment("");
   Print("GoldPro v5 stopped. Reason: ", reason);
}

//==========================================================================
//  OnTick
//==========================================================================
void OnTick()
{
   ResetDailyTracking();

   // Position management runs on every tick
   if(HasPosition())
      ManagePosition();

   RefreshChart();

   // Signal evaluation only on new bar
   datetime barTime = iTime(_Symbol, PERIOD_H1, 0);
   if(barTime == g_lastBarTime) return;
   g_lastBarTime = barTime;

   if(!LoadBuffers()) return;
   if(HasPosition())  return;

   if(g_acct.Balance() < InpMinBalance)
   { PrintFormat("[SKIP] Balance %.2f < minimum %.2f", g_acct.Balance(), InpMinBalance); return; }

   if(IsDailyDDBreached()) return;
   if(InpUseSession && !IsSessionActive()) return;

   int sig = GetSignal();
   if(sig ==  1) ExecuteBuy();
   if(sig == -1) ExecuteSell();
}

//==========================================================================
//  ManagePosition — Break-Even then Delayed Trailing Stop
//
//  Phase 1 (profit < InpBEATR × ATR):
//    Do nothing — let the trade breathe
//
//  Phase 2 (profit >= InpBEATR × ATR AND < InpTrailActivate × ATR):
//    Move SL to break-even + small buffer (InpBEBuffer × ATR)
//    This locks in zero-loss outcome
//
//  Phase 3 (profit >= InpTrailActivate × ATR):
//    Activate trailing stop at InpTrailATRMult × ATR distance
//    Trailing moves SL in favor direction only
//==========================================================================
void ManagePosition()
{
   if(CopyBuffer(g_hATR, 0, 0, 2, g_bufATR) < 2) return;
   double atr = g_bufATR[1];
   if(atr <= 0.0) return;

   double beDistPrice    = InpBEATR         * atr;  // profit needed to trigger BE
   double beBuffer       = InpBEBuffer      * atr;  // SL buffer above entry at BE
   double trailActiveDist= InpTrailActivate * atr;  // profit needed to start trailing
   double trailDist      = InpTrailATRMult  * atr;  // trailing distance

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i))                 continue;
      if(g_pos.Symbol() != _Symbol)               continue;
      if(g_pos.Magic() != (ulong)InpMagicNumber)  continue;

      ulong  tk    = g_pos.Ticket();
      double cSL   = g_pos.StopLoss();
      double cTP   = g_pos.TakeProfit();
      double op    = g_pos.PriceOpen();
      double newSL = cSL;

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
      {
         double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profit = bid - op;  // distance in price terms

         if(profit >= trailActiveDist)
         {
            //--- Phase 3: trailing stop active
            double trailSL = NormalizeDouble(bid - trailDist, _Digits);
            if(trailSL > cSL + _Point)
               newSL = trailSL;
         }
         else if(profit >= beDistPrice)
         {
            //--- Phase 2: move to break-even + buffer
            double beSL = NormalizeDouble(op + beBuffer, _Digits);
            if(beSL > cSL + _Point)
               newSL = beSL;
         }
         // Phase 1: do nothing

         if(newSL > cSL + _Point)
         {
            if(g_trade.PositionModify(tk, newSL, cTP))
            {
               string phase = (profit >= trailActiveDist) ? "TRAIL" : "BE";
               PrintFormat("[%s BUY] #%I64u SL: %.2f → %.2f  (Bid=%.2f, Profit=%.2f)",
                           phase, tk, cSL, newSL, bid, profit);
            }
         }
      }
      else if(g_pos.PositionType() == POSITION_TYPE_SELL)
      {
         double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = op - ask;  // distance in price terms

         if(profit >= trailActiveDist)
         {
            //--- Phase 3: trailing stop
            double trailSL = NormalizeDouble(ask + trailDist, _Digits);
            if(cSL == 0.0 || trailSL < cSL - _Point)
               newSL = trailSL;
         }
         else if(profit >= beDistPrice)
         {
            //--- Phase 2: break-even + buffer
            double beSL = NormalizeDouble(op - beBuffer, _Digits);
            if(cSL == 0.0 || beSL < cSL - _Point)
               newSL = beSL;
         }

         if(newSL > 0.0 && (cSL == 0.0 || newSL < cSL - _Point))
         {
            if(g_trade.PositionModify(tk, newSL, cTP))
            {
               string phase = (profit >= trailActiveDist) ? "TRAIL" : "BE";
               PrintFormat("[%s SELL] #%I64u SL: %.2f → %.2f  (Ask=%.2f, Profit=%.2f)",
                           phase, tk, cSL, newSL, ask, profit);
            }
         }
      }
   }
}

//==========================================================================
//  ResetDailyTracking
//==========================================================================
void ResetDailyTracking()
{
   MqlDateTime dtNow, dtLast;
   TimeToStruct(TimeCurrent(),  dtNow);
   TimeToStruct(g_lastDayReset, dtLast);
   if(dtNow.day != dtLast.day)
   {
      g_dayStartBal  = g_acct.Balance();
      g_lastDayReset = TimeCurrent();
      PrintFormat("[NEW DAY] %04d.%02d.%02d — Balance: %.2f",
                  dtNow.year, dtNow.mon, dtNow.day, g_dayStartBal);
   }
}

//==========================================================================
//  IsDailyDDBreached
//==========================================================================
bool IsDailyDDBreached()
{
   if(g_dayStartBal <= 0.0) return false;
   double ddPct = (g_dayStartBal - g_acct.Equity()) / g_dayStartBal * 100.0;
   if(ddPct >= InpMaxDailyDD)
   {
      PrintFormat("[DAILY DD] %.1f%% loss today — trading paused.", ddPct);
      return true;
   }
   return false;
}

//==========================================================================
//  IsSessionActive
//==========================================================================
bool IsSessionActive()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= InpSessionStart && dt.hour < InpSessionEnd);
}

//==========================================================================
//  LoadBuffers
//==========================================================================
bool LoadBuffers()
{
   const int N_SIG = 4;
   int N_ATR = InpVolATRPeriod + 4;

   if(CopyBuffer(g_hMACD,     0, 0, N_SIG, g_bufMACD)     < N_SIG) { Print("ERROR: CopyBuffer MACD");     return false; }
   if(CopyBuffer(g_hMACD,     1, 0, N_SIG, g_bufSignal)   < N_SIG) { Print("ERROR: CopyBuffer Signal");   return false; }
   if(CopyBuffer(g_hTrendEMA, 0, 0, N_SIG, g_bufTrendEMA) < N_SIG) { Print("ERROR: CopyBuffer TrendEMA"); return false; }
   if(CopyBuffer(g_hRSI,      0, 0, N_SIG, g_bufRSI)      < N_SIG) { Print("ERROR: CopyBuffer RSI");      return false; }
   if(CopyBuffer(g_hADX,      0, 0, N_SIG, g_bufADX)      < N_SIG) { Print("ERROR: CopyBuffer ADX");      return false; }
   if(CopyBuffer(g_hATR,      0, 0, N_ATR, g_bufATR)      < N_ATR) { Print("ERROR: CopyBuffer ATR");      return false; }

   return true;
}

//==========================================================================
//  CalcATRAverage
//==========================================================================
double CalcATRAverage()
{
   double sum = 0.0;
   for(int k = 1; k <= InpVolATRPeriod; k++)
      sum += g_bufATR[k];
   return sum / InpVolATRPeriod;
}

//==========================================================================
//  GetSignal
//==========================================================================
int GetSignal()
{
   double macdNow  = g_bufMACD[1],   macdPrev  = g_bufMACD[2];
   double sigNow   = g_bufSignal[1], sigPrev   = g_bufSignal[2];
   double trendNow = g_bufTrendEMA[1];
   double rsiNow   = g_bufRSI[1];
   double adxNow   = g_bufADX[1];
   double atrNow   = g_bufATR[1];
   double close1   = iClose(_Symbol, PERIOD_H1, 1);

   //--- Volatility filter
   double atrAvg = CalcATRAverage();
   if(atrNow < atrAvg * InpVolATRMult)
   {
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog >= 3600)
      {
         PrintFormat("[VOL FILTER] ATR=%.2f < AvgATR=%.2f × %.1f — skipping",
                     atrNow, atrAvg, InpVolATRMult);
         lastLog = TimeCurrent();
      }
      return 0;
   }

   //--- ADX filter
   if(adxNow < InpADXMinLevel) return 0;

   //--- MACD crossover
   bool bullCross = (macdPrev <= sigPrev) && (macdNow > sigNow);
   bool bearCross = (macdPrev >= sigPrev) && (macdNow < sigNow);

   //--- Trend alignment
   bool uptrend   = close1 > trendNow;
   bool downtrend = close1 < trendNow;

   //--- RSI zone
   bool rsiBuy  = (rsiNow >= 40.0) && (rsiNow < InpRSIOverbought);
   bool rsiSell = (rsiNow <= 60.0) && (rsiNow > InpRSIOversold);

   if(bullCross && uptrend && rsiBuy)
   {
      PrintFormat("[BUY SIG] %s | MACD=%.4f>%.4f | RSI=%.1f | ADX=%.1f | ATR=%.2f(Avg=%.2f)",
                  TimeToString(iTime(_Symbol,PERIOD_H1,1),TIME_DATE|TIME_MINUTES),
                  macdNow, sigNow, rsiNow, adxNow, atrNow, atrAvg);
      return 1;
   }
   if(bearCross && downtrend && rsiSell)
   {
      PrintFormat("[SELL SIG] %s | MACD=%.4f<%.4f | RSI=%.1f | ADX=%.1f | ATR=%.2f(Avg=%.2f)",
                  TimeToString(iTime(_Symbol,PERIOD_H1,1),TIME_DATE|TIME_MINUTES),
                  macdNow, sigNow, rsiNow, adxNow, atrNow, atrAvg);
      return -1;
   }
   return 0;
}

//==========================================================================
//  CalcLots
//==========================================================================
double CalcLots(double slDist)
{
   if(slDist <= 0.0) { Print("ERROR: CalcLots — slDist=0"); return 0.0; }

   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0.0 || tickVal <= 0.0) { Print("ERROR: CalcLots — bad tick data"); return 0.0; }

   double riskTarget = g_acct.Balance() * InpRiskPercent / 100.0;
   double lossPerLot = (slDist / tickSz) * tickVal;
   if(lossPerLot <= 0.0) return 0.0;

   double minLot     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double minLotLoss = minLot * lossPerLot;
   double maxAllowed = riskTarget * InpMaxLotRiskMult;

   if(minLotLoss > maxAllowed)
   {
      PrintFormat("[LOT GUARD] SKIP — min lot risks $%.2f > %.1f× target $%.2f. Need $%.0f+ balance",
                  minLotLoss, InpMaxLotRiskMult, riskTarget,
                  minLotLoss / (InpRiskPercent / 100.0));
      return 0.0;
   }

   double lots   = riskTarget / lossPerLot;
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   lots = MathFloor(lots / step) * step;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   PrintFormat("[LOTS] Bal=%.2f | Target=$%.2f | Actual=$%.2f (%.2f%%) | Lots=%.2f",
               g_acct.Balance(), riskTarget, lots * lossPerLot,
               lots * lossPerLot / g_acct.Balance() * 100.0, lots);
   return lots;
}

//==========================================================================
//  ExecuteBuy
//==========================================================================
void ExecuteBuy()
{
   double atr  = g_bufATR[1];
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double slD  = InpATRMultSL * atr;
   double tpD  = slD * InpRiskReward;
   double sl   = NormalizeDouble(ask - slD, _Digits);
   double tp   = NormalizeDouble(ask + tpD, _Digits);
   double lots = CalcLots(slD);

   if(lots <= 0.0)                            { Print("ERROR: Buy — lot=0"); return; }
   if(!CheckMargin(ORDER_TYPE_BUY, lots, ask)) return;

   PrintFormat("[BUY] Ask=%.2f | SL=%.2f | TP=%.2f | SLdist=%.2f | Lots=%.2f | ATR=%.2f",
               ask, sl, tp, slD, lots, atr);

   if(g_trade.Buy(lots, _Symbol, ask, sl, tp, InpComment))
      PrintFormat("[OK] BUY #%I64u @ %.2f", g_trade.ResultOrder(), g_trade.ResultPrice());
   else
      PrintFormat("[ERR] BUY failed %d: %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
}

//==========================================================================
//  ExecuteSell
//==========================================================================
void ExecuteSell()
{
   double atr  = g_bufATR[1];
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slD  = InpATRMultSL * atr;
   double tpD  = slD * InpRiskReward;
   double sl   = NormalizeDouble(bid + slD, _Digits);
   double tp   = NormalizeDouble(bid - tpD, _Digits);
   double lots = CalcLots(slD);

   if(lots <= 0.0)                              { Print("ERROR: Sell — lot=0"); return; }
   if(!CheckMargin(ORDER_TYPE_SELL, lots, bid)) return;

   PrintFormat("[SELL] Bid=%.2f | SL=%.2f | TP=%.2f | SLdist=%.2f | Lots=%.2f | ATR=%.2f",
               bid, sl, tp, slD, lots, atr);

   if(g_trade.Sell(lots, _Symbol, bid, sl, tp, InpComment))
      PrintFormat("[OK] SELL #%I64u @ %.2f", g_trade.ResultOrder(), g_trade.ResultPrice());
   else
      PrintFormat("[ERR] SELL failed %d: %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
}

//==========================================================================
//  HasPosition
//==========================================================================
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i)) continue;
      if(g_pos.Symbol() == _Symbol && g_pos.Magic() == (ulong)InpMagicNumber)
         return true;
   }
   return false;
}

//==========================================================================
//  CheckMargin
//==========================================================================
bool CheckMargin(ENUM_ORDER_TYPE type, double lots, double price)
{
   double margin;
   if(!OrderCalcMargin(type, _Symbol, lots, price, margin))
   { Print("ERROR: OrderCalcMargin failed"); return false; }
   if(g_acct.FreeMargin() < margin * 1.2)
   {
      PrintFormat("WARNING: FreeMargin %.2f < required %.2f", g_acct.FreeMargin(), margin * 1.2);
      return false;
   }
   return true;
}

//==========================================================================
//  DetectFillingMode
//==========================================================================
ENUM_ORDER_TYPE_FILLING DetectFillingMode()
{
   ENUM_SYMBOL_TRADE_EXECUTION execMode =
      (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE);
   if(execMode == SYMBOL_TRADE_EXECUTION_INSTANT ||
      execMode == SYMBOL_TRADE_EXECUTION_REQUEST)
      return ORDER_FILLING_RETURN;
   return ORDER_FILLING_IOC;
}

//==========================================================================
//  RefreshChart
//==========================================================================
void RefreshChart()
{
   double ddPct = (g_dayStartBal > 0.0)
                  ? MathMax(0.0, (g_dayStartBal - g_acct.Equity()) / g_dayStartBal * 100.0)
                  : 0.0;
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   bool inSession = (!InpUseSession || (dt.hour >= InpSessionStart && dt.hour < InpSessionEnd));

   string volStatus = "---";
   if(ArraySize(g_bufATR) > InpVolATRPeriod)
   {
      double atrNow = g_bufATR[1];
      double atrAvg = CalcATRAverage();
      double pct    = (atrAvg > 0) ? atrNow / atrAvg * 100.0 : 0;
      string ok     = (atrNow >= atrAvg * InpVolATRMult) ? "✓ ACTIVE" : "✗ QUIET";
      volStatus     = StringFormat("%.2f / %.2f (%.0f%%) %s", atrNow, atrAvg, pct, ok);
   }

   string D  = "\n";
   string hr = "────────────────────────────" + D;
   string s  = hr;
   s += "  GoldPro H1 EA  v5.00" + D;
   s += hr;
   s += StringFormat("Balance  : %.2f %s" + D, g_acct.Balance(), g_acct.Currency());
   s += StringFormat("Equity   : %.2f %s" + D, g_acct.Equity(),  g_acct.Currency());
   s += StringFormat("Daily DD : %.1f%% / %.1f%%" + D, ddPct, InpMaxDailyDD);
   s += StringFormat("Session  : %s" + D, inSession ? "ACTIVE" : "CLOSED");
   s += StringFormat("Volatility: %s" + D, volStatus);
   s += hr;

   if(HasPosition())
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!g_pos.SelectByIndex(i)) continue;
         if(g_pos.Symbol() != _Symbol || g_pos.Magic() != (ulong)InpMagicNumber) continue;

         string dir   = (g_pos.PositionType() == POSITION_TYPE_BUY) ? "▲ BUY" : "▼ SELL";
         double pnl   = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
         double op    = g_pos.PriceOpen();
         double cur   = g_pos.PriceCurrent();
         double atr   = (ArraySize(g_bufATR) > 1) ? g_bufATR[1] : 0;
         double profD = (g_pos.PositionType() == POSITION_TYPE_BUY) ? cur - op : op - cur;
         string phase = "Phase 1 (hold)";
         if(atr > 0)
         {
            if(profD >= InpTrailActivate * atr)      phase = "Phase 3 (trailing)";
            else if(profD >= InpBEATR * atr)         phase = "Phase 2 (break-even)";
         }
         s += StringFormat("Type     : %s" + D, dir);
         s += StringFormat("Lots     : %.2f" + D, g_pos.Volume());
         s += StringFormat("Open     : %.2f" + D, op);
         s += StringFormat("Current  : %.2f" + D, cur);
         s += StringFormat("SL       : %.2f" + D, g_pos.StopLoss());
         s += StringFormat("TP       : %.2f" + D, g_pos.TakeProfit());
         s += StringFormat("P/L      : %+.2f %s" + D, pnl, g_acct.Currency());
         s += StringFormat("Status   : %s" + D, phase);
      }
   }
   else
   {
      s += "Status   : Waiting for signal" + D;
      if(ArraySize(g_bufMACD) > 1)
      {
         s += StringFormat("MACD     : %.4f" + D, g_bufMACD[1]);
         s += StringFormat("Signal   : %.4f" + D, g_bufSignal[1]);
         s += StringFormat("Histogram: %+.4f" + D, g_bufMACD[1] - g_bufSignal[1]);
         s += StringFormat("TrndEMA  : %.2f" + D, g_bufTrendEMA[1]);
         s += StringFormat("RSI      : %.1f" + D, g_bufRSI[1]);
         s += StringFormat("ADX      : %.1f%s" + D, g_bufADX[1],
                           g_bufADX[1] < InpADXMinLevel ? " [CHOPPY]" : " [OK]");
      }
   }

   s += hr;
   s += StringFormat("MACD(%d/%d/%d) | EMA%d | Vol×%.1f" + D,
                     InpMACDFast, InpMACDSlow, InpMACDSignal, InpTrendEMA, InpVolATRMult);
   s += StringFormat("BE@+%.1f×ATR | Trail@+%.1f×ATR" + D, InpBEATR, InpTrailActivate);
   s += StringFormat("Risk %.1f%% | RR 1:%.1f | SL %.1f×ATR" + D,
                     InpRiskPercent, InpRiskReward, InpATRMultSL);
   Comment(s);
}
//+------------------------------------------------------------------+
