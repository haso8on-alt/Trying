//+------------------------------------------------------------------+
//|                                         GoldPro_H1_EA.mq5        |
//|                     Professional XAUUSD H1 Expert Advisor        |
//|          Strategy: MACD + 200 EMA + RSI + ADX + ATR             |
//|                            v3.00                                  |
//+------------------------------------------------------------------+
//
//  WHY MACD instead of EMA crossover?
//  EMA crossover is a lagging signal — by the time fast crosses slow,
//  the move is often exhausted, causing entries near reversal points.
//  MACD uses the same EMAs internally but triggers earlier via its
//  signal line, giving a better entry price and higher RR potential.
//
//+------------------------------------------------------------------+
#property copyright   "GoldPro EA v3.00"
#property version     "3.00"
#property description "XAUUSD H1 EA — MACD(12/26/9) + 200EMA + RSI + ADX | ATR Risk Mgmt"

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

input group "─── Risk Management ────────────────────────"
input double InpRiskPercent    = 1.0;  // Risk Per Trade (% of Balance)
input double InpATRMultSL      = 2.0;  // ATR Multiplier for Stop Loss (wider = less stopped out)
input double InpRiskReward     = 1.5;  // Risk:Reward Ratio (1.5 more achievable than 2.0)
input bool   InpUseTrailing    = true; // Enable ATR Trailing Stop
input double InpTrailATRMult   = 1.0;  // ATR Multiplier for Trailing Stop
input double InpMinBalance     = 500.0;// Minimum Balance Required ($)
input double InpMaxLotRiskMult = 2.0;  // Lot guard: skip if min-lot risk > X × target
input double InpMaxDailyDD     = 3.0;  // Max Daily Drawdown (%) — halt trading if hit

input group "─── Session Filter ──────────────────────────"
input bool   InpUseSession    = true;  // Enable Session Filter
input int    InpSessionStart  = 8;     // Session Start Hour (Server/UTC time)
input int    InpSessionEnd    = 22;    // Session End Hour   (Server/UTC time)

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

double g_bufMACD[];     // MACD main line    (iMACD buffer 0)
double g_bufSignal[];   // MACD signal line  (iMACD buffer 1)
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
   //--- Validate parameters
   if(InpMACDFast >= InpMACDSlow)
   {
      Print("ERROR: MACD Fast (", InpMACDFast, ") must be < MACD Slow (", InpMACDSlow, ")");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
   {
      Print("ERROR: RiskPercent must be 0.01–10. Got: ", InpRiskPercent);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRiskReward < 1.0)
   {
      Print("ERROR: RiskReward must be >= 1.0. Got: ", InpRiskReward);
      return INIT_PARAMETERS_INCORRECT;
   }

   //--- Configure trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(DetectFillingMode());
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   //--- Create indicator handles (always on H1)
   g_hMACD     = iMACD(_Symbol, PERIOD_H1, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hTrendEMA = iMA  (_Symbol, PERIOD_H1, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI (_Symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);
   g_hADX      = iADX (_Symbol, PERIOD_H1, InpADXPeriod);
   g_hATR      = iATR (_Symbol, PERIOD_H1, InpATRPeriod);

   if(g_hMACD     == INVALID_HANDLE || g_hTrendEMA == INVALID_HANDLE ||
      g_hRSI      == INVALID_HANDLE || g_hADX      == INVALID_HANDLE ||
      g_hATR      == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handle(s)!");
      return INIT_FAILED;
   }

   //--- Set as time-series
   ArraySetAsSeries(g_bufMACD,     true);
   ArraySetAsSeries(g_bufSignal,   true);
   ArraySetAsSeries(g_bufTrendEMA, true);
   ArraySetAsSeries(g_bufRSI,      true);
   ArraySetAsSeries(g_bufADX,      true);
   ArraySetAsSeries(g_bufATR,      true);

   //--- Daily drawdown tracking
   g_dayStartBal  = g_acct.Balance();
   g_lastDayReset = TimeCurrent();

   PrintFormat("══════════════════════════════════════════════════");
   PrintFormat("  GoldPro H1 EA v3.00 — Initialized");
   PrintFormat("  Symbol  : %s  |  Timeframe : H1", _Symbol);
   PrintFormat("  MACD    : %d / %d / %d", InpMACDFast, InpMACDSlow, InpMACDSignal);
   PrintFormat("  TrendEMA: %d  |  RSI: %d  |  ADX Min: %.0f", InpTrendEMA, InpRSIPeriod, InpADXMinLevel);
   PrintFormat("  ATR     : %d  (SL=%.1fx, Trail=%.1fx)", InpATRPeriod, InpATRMultSL, InpTrailATRMult);
   PrintFormat("  Risk    : %.1f%%  |  RR: 1:%.1f  |  MaxDailyDD: %.1f%%",
               InpRiskPercent, InpRiskReward, InpMaxDailyDD);
   PrintFormat("  Session : %s  (%02d:00–%02d:00 server time)",
               InpUseSession ? "ON" : "OFF", InpSessionStart, InpSessionEnd);
   PrintFormat("  Magic   : %d", InpMagicNumber);
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
   Print("GoldPro EA stopped. Reason: ", reason);
}

//==========================================================================
//  OnTick
//==========================================================================
void OnTick()
{
   ResetDailyTracking();

   if(InpUseTrailing && HasPosition())
      ApplyTrailing();

   RefreshChart();

   //--- New bar gate
   datetime barTime = iTime(_Symbol, PERIOD_H1, 0);
   if(barTime == g_lastBarTime) return;
   g_lastBarTime = barTime;

   if(!LoadBuffers()) return;
   if(HasPosition())  return;

   if(g_acct.Balance() < InpMinBalance)
   {
      PrintFormat("[SKIP] Balance %.2f < minimum %.2f", g_acct.Balance(), InpMinBalance);
      return;
   }
   if(IsDailyDDBreached()) return;
   if(InpUseSession && !IsSessionActive()) return;

   int sig = GetSignal();
   if(sig ==  1) ExecuteBuy();
   if(sig == -1) ExecuteSell();
}

//==========================================================================
//  ResetDailyTracking
//==========================================================================
void ResetDailyTracking()
{
   MqlDateTime dtNow, dtLast;
   TimeToStruct(TimeCurrent(),   dtNow);
   TimeToStruct(g_lastDayReset,  dtLast);
   if(dtNow.day != dtLast.day)
   {
      g_dayStartBal  = g_acct.Balance();
      g_lastDayReset = TimeCurrent();
      PrintFormat("[NEW DAY] %04d.%02d.%02d — Day start balance: %.2f",
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
      PrintFormat("[DAILY DD] %.1f%% loss today. Trading paused for today.", ddPct);
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
   const int N = 4;
   if(CopyBuffer(g_hMACD,     0, 0, N, g_bufMACD)     < N) { Print("ERROR: CopyBuffer MACD main");    return false; }
   if(CopyBuffer(g_hMACD,     1, 0, N, g_bufSignal)   < N) { Print("ERROR: CopyBuffer MACD signal");  return false; }
   if(CopyBuffer(g_hTrendEMA, 0, 0, N, g_bufTrendEMA) < N) { Print("ERROR: CopyBuffer TrendEMA");     return false; }
   if(CopyBuffer(g_hRSI,      0, 0, N, g_bufRSI)      < N) { Print("ERROR: CopyBuffer RSI");          return false; }
   if(CopyBuffer(g_hADX,      0, 0, N, g_bufADX)      < N) { Print("ERROR: CopyBuffer ADX");          return false; }
   if(CopyBuffer(g_hATR,      0, 0, N, g_bufATR)      < N) { Print("ERROR: CopyBuffer ATR");          return false; }
   return true;
}

//==========================================================================
//  GetSignal — 1=Buy  -1=Sell  0=No signal
//
//  Entry logic (all conditions must be true):
//    1. ADX > InpADXMinLevel       → market is trending, not choppy
//    2. MACD line crosses Signal    → momentum shift confirmed
//    3. Price above/below 200 EMA  → macro trend alignment
//    4. MACD cross happens below/above zero line → catching early momentum
//    5. RSI in valid zone           → not exhausted/extreme
//==========================================================================
int GetSignal()
{
   double macdNow    = g_bufMACD[1],   macdPrev    = g_bufMACD[2];
   double sigNow     = g_bufSignal[1], sigPrev     = g_bufSignal[2];
   double trendNow   = g_bufTrendEMA[1];
   double rsiNow     = g_bufRSI[1];
   double adxNow     = g_bufADX[1];
   double close1     = iClose(_Symbol, PERIOD_H1, 1);

   //--- 1. ADX: confirm trend, skip ranging market
   if(adxNow < InpADXMinLevel) return 0;

   //--- 2. MACD crossover on last closed bar
   bool bullCross = (macdPrev <= sigPrev) && (macdNow > sigNow);
   bool bearCross = (macdPrev >= sigPrev) && (macdNow < sigNow);

   //--- 3. Macro trend alignment
   bool uptrend   = close1 > trendNow;
   bool downtrend = close1 < trendNow;

   //--- 4. Cross quality: prefer crosses near zero line (fresher momentum)
   //       Allow cross anywhere below 0 for bull, above 0 for bear
   //       but not if MACD is extremely extended (late entry)
   bool macdBuyZone  = macdNow < 0 || (macdNow > 0 && macdNow < MathAbs(sigNow) * 3.0);
   bool macdSellZone = macdNow > 0 || (macdNow < 0 && macdNow > -MathAbs(sigNow) * 3.0);

   //--- 5. RSI confirmation
   bool rsiBuy  = (rsiNow >= 40.0) && (rsiNow < InpRSIOverbought);
   bool rsiSell = (rsiNow <= 60.0) && (rsiNow > InpRSIOversold);

   if(bullCross && uptrend && rsiBuy && macdBuyZone)
   {
      PrintFormat("[BUY SIG] %s | MACD=%.4f>Sig=%.4f | Trend=%.2f | RSI=%.1f | ADX=%.1f",
                  TimeToString(iTime(_Symbol,PERIOD_H1,1),TIME_DATE|TIME_MINUTES),
                  macdNow, sigNow, trendNow, rsiNow, adxNow);
      return 1;
   }
   if(bearCross && downtrend && rsiSell && macdSellZone)
   {
      PrintFormat("[SELL SIG] %s | MACD=%.4f<Sig=%.4f | Trend=%.2f | RSI=%.1f | ADX=%.1f",
                  TimeToString(iTime(_Symbol,PERIOD_H1,1),TIME_DATE|TIME_MINUTES),
                  macdNow, sigNow, trendNow, rsiNow, adxNow);
      return -1;
   }
   return 0;
}

//==========================================================================
//  CalcLots — risk-based position sizing with minimum-lot guard
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

   //--- Guard: check if even minimum lot risks too much
   double minLot     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double minLotLoss = minLot * lossPerLot;
   double maxAllowed = riskTarget * InpMaxLotRiskMult;

   if(minLotLoss > maxAllowed)
   {
      PrintFormat("[LOT GUARD] Skipping — min lot risks $%.2f > %.1f× target $%.2f. Need balance >= $%.0f",
                  minLotLoss, InpMaxLotRiskMult, riskTarget, minLotLoss / (InpRiskPercent / 100.0));
      return 0.0;
   }

   double lots   = riskTarget / lossPerLot;
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   lots = MathFloor(lots / step) * step;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   double actualRisk = lots * lossPerLot;
   PrintFormat("[LOTS] Bal=%.2f | Target=$%.2f | Actual=$%.2f (%.2f%%) | Lots=%.2f | SL=%.2f",
               g_acct.Balance(), riskTarget, actualRisk,
               actualRisk / g_acct.Balance() * 100.0, lots, slDist);
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

   if(lots <= 0.0)                            { Print("ERROR: Buy — lot calc returned 0"); return; }
   if(!CheckMargin(ORDER_TYPE_BUY, lots, ask)) return;

   PrintFormat("[BUY] Ask=%.2f | SL=%.2f | TP=%.2f | SLdist=%.2f | Lots=%.2f | ATR=%.2f",
               ask, sl, tp, slD, lots, atr);

   if(g_trade.Buy(lots, _Symbol, ask, sl, tp, InpComment))
      PrintFormat("[OK] BUY #%I64u @ %.2f", g_trade.ResultOrder(), g_trade.ResultPrice());
   else
      PrintFormat("[ERR] BUY failed — %d : %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
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

   if(lots <= 0.0)                              { Print("ERROR: Sell — lot calc returned 0"); return; }
   if(!CheckMargin(ORDER_TYPE_SELL, lots, bid)) return;

   PrintFormat("[SELL] Bid=%.2f | SL=%.2f | TP=%.2f | SLdist=%.2f | Lots=%.2f | ATR=%.2f",
               bid, sl, tp, slD, lots, atr);

   if(g_trade.Sell(lots, _Symbol, bid, sl, tp, InpComment))
      PrintFormat("[OK] SELL #%I64u @ %.2f", g_trade.ResultOrder(), g_trade.ResultPrice());
   else
      PrintFormat("[ERR] SELL failed — %d : %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
}

//==========================================================================
//  ApplyTrailing
//==========================================================================
void ApplyTrailing()
{
   if(CopyBuffer(g_hATR, 0, 0, 2, g_bufATR) < 2) return;
   double trailD = InpTrailATRMult * g_bufATR[1];
   if(trailD <= 0.0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i))                        continue;
      if(g_pos.Symbol() != _Symbol)                      continue;
      if(g_pos.Magic()  != (ulong)InpMagicNumber)        continue;

      ulong  tk  = g_pos.Ticket();
      double cSL = g_pos.StopLoss();
      double cTP = g_pos.TakeProfit();
      double op  = g_pos.PriceOpen();

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double nSL = NormalizeDouble(bid - trailD, _Digits);
         if(nSL > cSL + _Point && nSL > op)
            if(g_trade.PositionModify(tk, nSL, cTP))
               PrintFormat("[TRAIL BUY]  #%I64u  %.2f → %.2f", tk, cSL, nSL);
      }
      else if(g_pos.PositionType() == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double nSL = NormalizeDouble(ask + trailD, _Digits);
         if((cSL == 0.0 || nSL < cSL - _Point) && nSL < op)
            if(g_trade.PositionModify(tk, nSL, cTP))
               PrintFormat("[TRAIL SELL] #%I64u  %.2f → %.2f", tk, cSL, nSL);
      }
   }
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
   {
      Print("ERROR: OrderCalcMargin failed");
      return false;
   }
   if(g_acct.FreeMargin() < margin * 1.2)
   {
      PrintFormat("WARNING: Free margin %.2f < required %.2f (×1.2)", g_acct.FreeMargin(), margin * 1.2);
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
                  ? MathMax(0, (g_dayStartBal - g_acct.Equity()) / g_dayStartBal * 100.0)
                  : 0.0;

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   bool inSession = (!InpUseSession || (dt.hour >= InpSessionStart && dt.hour < InpSessionEnd));

   string D  = "\n";
   string hr = "────────────────────────────" + D;
   string s  = hr;
   s += "  GoldPro H1 EA  v3.00" + D;
   s += hr;
   s += StringFormat("Balance  : %.2f %s"  + D, g_acct.Balance(),    g_acct.Currency());
   s += StringFormat("Equity   : %.2f %s"  + D, g_acct.Equity(),     g_acct.Currency());
   s += StringFormat("Daily DD : %.1f%% / %.1f%%" + D, ddPct, InpMaxDailyDD);
   s += StringFormat("Session  : %s" + D, inSession ? "ACTIVE" : "CLOSED");
   s += hr;

   if(HasPosition())
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!g_pos.SelectByIndex(i)) continue;
         if(g_pos.Symbol() != _Symbol || g_pos.Magic() != (ulong)InpMagicNumber) continue;
         string dir = (g_pos.PositionType() == POSITION_TYPE_BUY) ? "▲ BUY" : "▼ SELL";
         double pnl = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
         s += StringFormat("Type     : %s" + D, dir);
         s += StringFormat("Lots     : %.2f" + D, g_pos.Volume());
         s += StringFormat("Open     : %.2f" + D, g_pos.PriceOpen());
         s += StringFormat("Current  : %.2f" + D, g_pos.PriceCurrent());
         s += StringFormat("SL       : %.2f" + D, g_pos.StopLoss());
         s += StringFormat("TP       : %.2f" + D, g_pos.TakeProfit());
         s += StringFormat("P/L      : %+.2f %s" + D, pnl, g_acct.Currency());
      }
   }
   else
   {
      s += "Status   : Waiting for signal" + D;
      if(ArraySize(g_bufMACD) > 1)
      {
         double hist = g_bufMACD[1] - g_bufSignal[1];
         s += StringFormat("MACD     : %.4f" + D, g_bufMACD[1]);
         s += StringFormat("Signal   : %.4f" + D, g_bufSignal[1]);
         s += StringFormat("Hist     : %+.4f" + D, hist);
         s += StringFormat("TrndEMA  : %.2f" + D, g_bufTrendEMA[1]);
         s += StringFormat("RSI      : %.1f" + D, g_bufRSI[1]);
         s += StringFormat("ADX      : %.1f%s" + D, g_bufADX[1],
                           g_bufADX[1] < InpADXMinLevel ? " [CHOPPY]" : " [OK]");
      }
   }
   s += hr;
   s += StringFormat("MACD(%d/%d/%d) | EMA%d | ADX>%.0f" + D,
                     InpMACDFast, InpMACDSlow, InpMACDSignal, InpTrendEMA, InpADXMinLevel);
   s += StringFormat("Risk %.1f%% | RR 1:%.1f | SL %.1fxATR" + D,
                     InpRiskPercent, InpRiskReward, InpATRMultSL);
   Comment(s);
}
//+------------------------------------------------------------------+
