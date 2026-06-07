//+------------------------------------------------------------------+
//|                                         GoldPro_H1_EA.mq5        |
//|                     Professional XAUUSD H1 Expert Advisor        |
//|         Strategy: EMA Crossover + RSI + ADX + ATR Risk Mgmt      |
//|                            v2.00                                  |
//+------------------------------------------------------------------+
#property copyright   "GoldPro EA v2.00"
#property version     "2.00"
#property description "XAUUSD H1 EA — EMA + RSI + ADX + ATR | v2 with lot-risk guard & session filter"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//==========================================================================
//  INPUTS
//==========================================================================

input group "─── Strategy ───────────────────────────────"
input int    InpFastEMA       = 21;    // Fast EMA Period
input int    InpSlowEMA       = 50;    // Slow EMA Period
input int    InpTrendEMA      = 200;   // Trend Filter EMA Period
input int    InpRSIPeriod     = 14;    // RSI Period
input double InpRSIOverbought = 70.0;  // RSI Overbought Level
input double InpRSIOversold   = 30.0;  // RSI Oversold Level
input int    InpADXPeriod     = 14;    // ADX Period
input double InpADXMinLevel   = 25.0;  // ADX Minimum — skip trades below this (25 = stronger filter)
input int    InpATRPeriod     = 14;    // ATR Period

input group "─── Risk Management ────────────────────────"
input double InpRiskPercent    = 1.0;  // Risk Per Trade (% of Balance)
input double InpATRMultSL      = 1.5;  // ATR Multiplier for Stop Loss
input double InpRiskReward     = 2.0;  // Risk:Reward Ratio (1 : X)
input bool   InpUseTrailing    = true; // Enable ATR Trailing Stop
input double InpTrailATRMult   = 1.0;  // ATR Multiplier for Trailing Stop
input double InpMinBalance     = 500.0;// Minimum Balance Required ($) — raise for XAUUSD
input double InpMaxLotRiskMult = 2.0;  // Max lot-risk multiplier: skip if min-lot risk > X × target risk
input double InpMaxDailyDD     = 3.0;  // Max Daily Drawdown (%) — stop trading if hit

input group "─── Session Filter ──────────────────────────"
input bool   InpUseSession    = true;  // Enable Session Filter
input int    InpSessionStart  = 8;     // Session Start Hour (Server Time, UTC)
input int    InpSessionEnd    = 22;    // Session End Hour   (Server Time, UTC)

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

int g_hFastEMA  = INVALID_HANDLE;
int g_hSlowEMA  = INVALID_HANDLE;
int g_hTrendEMA = INVALID_HANDLE;
int g_hRSI      = INVALID_HANDLE;
int g_hADX      = INVALID_HANDLE;
int g_hATR      = INVALID_HANDLE;

double g_bufFastEMA[];
double g_bufSlowEMA[];
double g_bufTrendEMA[];
double g_bufRSI[];
double g_bufADX[];
double g_bufATR[];

datetime g_lastBarTime  = 0;
double   g_dayStartBal  = 0.0;   // balance at start of trading day
datetime g_lastDayReset = 0;     // timestamp of last daily reset

//==========================================================================
//  OnInit
//==========================================================================
int OnInit()
{
   //--- Parameter validation
   if(InpFastEMA >= InpSlowEMA)
   {
      Print("ERROR: FastEMA (", InpFastEMA, ") must be < SlowEMA (", InpSlowEMA, ")");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSlowEMA >= InpTrendEMA)
   {
      Print("ERROR: SlowEMA (", InpSlowEMA, ") must be < TrendEMA (", InpTrendEMA, ")");
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
   if(InpSessionStart >= InpSessionEnd)
   {
      Print("ERROR: SessionStart must be < SessionEnd");
      return INIT_PARAMETERS_INCORRECT;
   }

   //--- Configure trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(DetectFillingMode());
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   //--- Create indicator handles (always H1)
   g_hFastEMA  = iMA(_Symbol, PERIOD_H1, InpFastEMA,  0, MODE_EMA, PRICE_CLOSE);
   g_hSlowEMA  = iMA(_Symbol, PERIOD_H1, InpSlowEMA,  0, MODE_EMA, PRICE_CLOSE);
   g_hTrendEMA = iMA(_Symbol, PERIOD_H1, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI      = iRSI(_Symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);
   g_hADX      = iADX(_Symbol, PERIOD_H1, InpADXPeriod);
   g_hATR      = iATR(_Symbol, PERIOD_H1, InpATRPeriod);

   if(g_hFastEMA  == INVALID_HANDLE || g_hSlowEMA  == INVALID_HANDLE ||
      g_hTrendEMA == INVALID_HANDLE || g_hRSI      == INVALID_HANDLE ||
      g_hADX      == INVALID_HANDLE || g_hATR      == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create one or more indicator handles!");
      return INIT_FAILED;
   }

   //--- Set buffers as time-series
   ArraySetAsSeries(g_bufFastEMA,  true);
   ArraySetAsSeries(g_bufSlowEMA,  true);
   ArraySetAsSeries(g_bufTrendEMA, true);
   ArraySetAsSeries(g_bufRSI,      true);
   ArraySetAsSeries(g_bufADX,      true);
   ArraySetAsSeries(g_bufATR,      true);

   //--- Snapshot balance for daily DD tracking
   g_dayStartBal  = g_acct.Balance();
   g_lastDayReset = TimeCurrent();

   PrintFormat("══════════════════════════════════════════════════");
   PrintFormat("  GoldPro H1 EA v2.00 — Initialized Successfully");
   PrintFormat("  Symbol : %s  |  Timeframe : H1", _Symbol);
   PrintFormat("  EMA    : %d / %d / %d", InpFastEMA, InpSlowEMA, InpTrendEMA);
   PrintFormat("  RSI    : %d  (OB=%.0f / OS=%.0f)", InpRSIPeriod, InpRSIOverbought, InpRSIOversold);
   PrintFormat("  ADX    : %d  (Min=%.0f)", InpADXPeriod, InpADXMinLevel);
   PrintFormat("  ATR    : %d  (SL=%.1fx, Trail=%.1fx)", InpATRPeriod, InpATRMultSL, InpTrailATRMult);
   PrintFormat("  Risk   : %.1f%%  |  RR: 1:%.1f  |  MaxDD/day: %.1f%%",
               InpRiskPercent, InpRiskReward, InpMaxDailyDD);
   PrintFormat("  Session: %s  (%02d:00 – %02d:00 server time)",
               InpUseSession ? "ON" : "OFF", InpSessionStart, InpSessionEnd);
   PrintFormat("  LotGuard: skip if min-lot risk > %.1f× target", InpMaxLotRiskMult);
   PrintFormat("  Magic  : %d  |  Slippage: %d pts", InpMagicNumber, InpSlippage);
   PrintFormat("══════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
}

//==========================================================================
//  OnDeinit
//==========================================================================
void OnDeinit(const int reason)
{
   if(g_hFastEMA  != INVALID_HANDLE) IndicatorRelease(g_hFastEMA);
   if(g_hSlowEMA  != INVALID_HANDLE) IndicatorRelease(g_hSlowEMA);
   if(g_hTrendEMA != INVALID_HANDLE) IndicatorRelease(g_hTrendEMA);
   if(g_hRSI      != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   if(g_hADX      != INVALID_HANDLE) IndicatorRelease(g_hADX);
   if(g_hATR      != INVALID_HANDLE) IndicatorRelease(g_hATR);
   Comment("");
   PrintFormat("GoldPro EA stopped. Reason: %d", reason);
}

//==========================================================================
//  OnTick
//==========================================================================
void OnTick()
{
   //--- Reset daily balance snapshot at the start of each new day
   ResetDailyTracking();

   //--- Trailing stop runs on every tick
   if(InpUseTrailing && HasPosition())
      ApplyTrailing();

   //--- Refresh chart overlay
   RefreshChart();

   //--- New bar gate
   datetime barTime = iTime(_Symbol, PERIOD_H1, 0);
   if(barTime == g_lastBarTime) return;
   g_lastBarTime = barTime;

   //--- Load indicators
   if(!LoadBuffers()) return;

   //--- No new positions if one already open
   if(HasPosition()) return;

   //--- Minimum balance check
   if(g_acct.Balance() < InpMinBalance)
   {
      PrintFormat("[SKIP] Balance %.2f < MinBalance %.2f", g_acct.Balance(), InpMinBalance);
      return;
   }

   //--- Daily drawdown guard
   if(IsDailyDDBreached()) return;

   //--- Session filter
   if(InpUseSession && !IsSessionActive()) return;

   //--- Signal → trade
   int sig = GetSignal();
   if(sig ==  1) ExecuteBuy();
   if(sig == -1) ExecuteSell();
}

//==========================================================================
//  ResetDailyTracking — refresh day-start balance at midnight
//==========================================================================
void ResetDailyTracking()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   MqlDateTime dtLast;
   TimeToStruct(g_lastDayReset, dtLast);

   if(dt.day != dtLast.day)
   {
      g_dayStartBal  = g_acct.Balance();
      g_lastDayReset = TimeCurrent();
      PrintFormat("[DAY RESET] New day %04d.%02d.%02d — Day start balance: %.2f",
                  dt.year, dt.mon, dt.day, g_dayStartBal);
   }
}

//==========================================================================
//  IsDailyDDBreached — returns true if daily loss limit reached
//==========================================================================
bool IsDailyDDBreached()
{
   if(g_dayStartBal <= 0.0) return false;

   double equity  = g_acct.Equity();
   double ddPct   = (g_dayStartBal - equity) / g_dayStartBal * 100.0;

   if(ddPct >= InpMaxDailyDD)
   {
      PrintFormat("[DAILY DD] %.1f%% loss today (%.2f → %.2f). Trading suspended for today.",
                  ddPct, g_dayStartBal, equity);
      return true;
   }
   return false;
}

//==========================================================================
//  IsSessionActive — true if current server time is within allowed window
//==========================================================================
bool IsSessionActive()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool active = (dt.hour >= InpSessionStart && dt.hour < InpSessionEnd);
   return active;
}

//==========================================================================
//  LoadBuffers
//==========================================================================
bool LoadBuffers()
{
   const int N = 4;
   if(CopyBuffer(g_hFastEMA,  0, 0, N, g_bufFastEMA)  < N) { Print("ERROR: CopyBuffer FastEMA");  return false; }
   if(CopyBuffer(g_hSlowEMA,  0, 0, N, g_bufSlowEMA)  < N) { Print("ERROR: CopyBuffer SlowEMA");  return false; }
   if(CopyBuffer(g_hTrendEMA, 0, 0, N, g_bufTrendEMA) < N) { Print("ERROR: CopyBuffer TrendEMA"); return false; }
   if(CopyBuffer(g_hRSI,      0, 0, N, g_bufRSI)      < N) { Print("ERROR: CopyBuffer RSI");      return false; }
   if(CopyBuffer(g_hADX,      0, 0, N, g_bufADX)      < N) { Print("ERROR: CopyBuffer ADX");      return false; }
   if(CopyBuffer(g_hATR,      0, 0, N, g_bufATR)      < N) { Print("ERROR: CopyBuffer ATR");      return false; }
   return true;
}

//==========================================================================
//  GetSignal — 1=Buy  -1=Sell  0=No signal
//
//  Conditions (all must be true simultaneously):
//    1. ADX > threshold        → confirmed trend, not choppy
//    2. EMA(fast) × EMA(slow)  → fresh crossover on last closed bar
//    3. Price + FastEMA both on correct side of EMA(200) → macro trend
//    4. RSI in valid momentum zone (not extreme)
//==========================================================================
int GetSignal()
{
   double fastNow  = g_bufFastEMA[1],  fastPrev  = g_bufFastEMA[2];
   double slowNow  = g_bufSlowEMA[1],  slowPrev  = g_bufSlowEMA[2];
   double trendNow = g_bufTrendEMA[1];
   double rsiNow   = g_bufRSI[1];
   double adxNow   = g_bufADX[1];
   double close1   = iClose(_Symbol, PERIOD_H1, 1);

   if(adxNow < InpADXMinLevel) return 0;

   bool bullCross = (fastPrev <= slowPrev) && (fastNow > slowNow);
   bool bearCross = (fastPrev >= slowPrev) && (fastNow < slowNow);

   bool uptrend   = (close1 > trendNow) && (fastNow > trendNow);
   bool downtrend = (close1 < trendNow) && (fastNow < trendNow);

   bool rsiBuy    = (rsiNow >= 45.0) && (rsiNow < InpRSIOverbought);
   bool rsiSell   = (rsiNow <= 55.0) && (rsiNow > InpRSIOversold);

   if(bullCross && uptrend && rsiBuy)
   {
      PrintFormat("[BUY SIG] %s | EMA=%.2f>%.2f | Trend=%.2f | RSI=%.1f | ADX=%.1f",
                  TimeToString(iTime(_Symbol,PERIOD_H1,1),TIME_DATE|TIME_MINUTES),
                  fastNow, slowNow, trendNow, rsiNow, adxNow);
      return 1;
   }
   if(bearCross && downtrend && rsiSell)
   {
      PrintFormat("[SELL SIG] %s | EMA=%.2f<%.2f | Trend=%.2f | RSI=%.1f | ADX=%.1f",
                  TimeToString(iTime(_Symbol,PERIOD_H1,1),TIME_DATE|TIME_MINUTES),
                  fastNow, slowNow, trendNow, rsiNow, adxNow);
      return -1;
   }
   return 0;
}

//==========================================================================
//  CalcLots — risk-based position sizing with minimum-lot guard
//
//  KEY FIX v2: If minimum lot would risk more than InpMaxLotRiskMult × target,
//  we skip the trade completely rather than silently over-risk the account.
//  This protects small accounts (e.g. $200) from XAUUSD lot constraints.
//==========================================================================
double CalcLots(double slDist)
{
   if(slDist <= 0.0) { Print("ERROR: CalcLots — slDist=0"); return 0.0; }

   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0.0 || tickVal <= 0.0) { Print("ERROR: CalcLots — bad tick data"); return 0.0; }

   double riskTarget  = g_acct.Balance() * InpRiskPercent / 100.0;
   double lossPerLot  = (slDist / tickSz) * tickVal;
   if(lossPerLot <= 0.0) return 0.0;

   //--- Check if minimum lot already exceeds acceptable risk
   double minLot       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double minLotLoss   = minLot * lossPerLot;                       // actual loss at min lot
   double maxAllowed   = riskTarget * InpMaxLotRiskMult;            // e.g. 2× target

   if(minLotLoss > maxAllowed)
   {
      PrintFormat("[LOT GUARD] SKIP — min lot (%.2f) would risk $%.2f > %.1f× target $%.2f. "
                  "Increase balance or reduce ATR_SL multiplier.",
                  minLot, minLotLoss, InpMaxLotRiskMult, riskTarget);
      return 0.0;
   }

   double lots   = riskTarget / lossPerLot;
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   lots = MathFloor(lots / step) * step;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   //--- Verify actual risk after rounding
   double actualRisk = lots * lossPerLot;
   PrintFormat("[LOTS] Balance=%.2f | Target risk=$%.2f | Actual risk=$%.2f (%.2f%%) | Lots=%.2f",
               g_acct.Balance(), riskTarget, actualRisk,
               actualRisk / g_acct.Balance() * 100.0, lots);
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

   if(lots <= 0.0)                            { Print("ERROR: ExecuteBuy — lot calc returned 0"); return; }
   if(!CheckMargin(ORDER_TYPE_BUY, lots, ask)) return;

   PrintFormat("[BUY] Ask=%.2f | SL=%.2f (-$%.0f) | TP=%.2f (+$%.0f) | Lots=%.2f | ATR=%.2f",
               ask, sl, slD, tp, tpD, lots, atr);

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

   if(lots <= 0.0)                              { Print("ERROR: ExecuteSell — lot calc returned 0"); return; }
   if(!CheckMargin(ORDER_TYPE_SELL, lots, bid)) return;

   PrintFormat("[SELL] Bid=%.2f | SL=%.2f (+$%.0f) | TP=%.2f (-$%.0f) | Lots=%.2f | ATR=%.2f",
               bid, sl, slD, tp, tpD, lots, atr);

   if(g_trade.Sell(lots, _Symbol, bid, sl, tp, InpComment))
      PrintFormat("[OK] SELL #%I64u @ %.2f", g_trade.ResultOrder(), g_trade.ResultPrice());
   else
      PrintFormat("[ERR] SELL failed — %d : %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
}

//==========================================================================
//  ApplyTrailing — ATR trailing stop, moves only in favorable direction,
//  activates only after trade enters profit
//==========================================================================
void ApplyTrailing()
{
   if(CopyBuffer(g_hATR, 0, 0, 2, g_bufATR) < 2) return;
   double trailD = InpTrailATRMult * g_bufATR[1];
   if(trailD <= 0.0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i))                       continue;
      if(g_pos.Symbol() != _Symbol)                     continue;
      if(g_pos.Magic()  != (ulong)InpMagicNumber)       continue;

      ulong  tk  = g_pos.Ticket();
      double cSL = g_pos.StopLoss();
      double cTP = g_pos.TakeProfit();
      double op  = g_pos.PriceOpen();

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double nSL = NormalizeDouble(bid - trailD, _Digits);
         if(nSL > cSL + _Point && nSL > op)
         {
            if(g_trade.PositionModify(tk, nSL, cTP))
               PrintFormat("[TRAIL BUY]  #%I64u  %.2f → %.2f", tk, cSL, nSL);
         }
      }
      else if(g_pos.PositionType() == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double nSL = NormalizeDouble(ask + trailD, _Digits);
         if((cSL == 0.0 || nSL < cSL - _Point) && nSL < op)
         {
            if(g_trade.PositionModify(tk, nSL, cTP))
               PrintFormat("[TRAIL SELL] #%I64u  %.2f → %.2f", tk, cSL, nSL);
         }
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
//  DetectFillingMode — uses SYMBOL_TRADE_EXEMODE (all MT5 builds)
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
   string D  = "\n";
   string hr = "────────────────────────────" + D;

   double ddPct = (g_dayStartBal > 0)
                  ? (g_dayStartBal - g_acct.Equity()) / g_dayStartBal * 100.0
                  : 0.0;
   string ddStr = StringFormat("%.1f%% / %.1f%%", MathMax(0, ddPct), InpMaxDailyDD);

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   string sessionStr = (InpUseSession && (dt.hour < InpSessionStart || dt.hour >= InpSessionEnd))
                       ? " [OUT OF SESSION]" : "";

   string s  = hr;
   s += "  GoldPro H1 EA  v2.00" + D;
   s += hr;
   s += StringFormat("Balance  : %.2f %s"   + D, g_acct.Balance(),    g_acct.Currency());
   s += StringFormat("Equity   : %.2f %s"   + D, g_acct.Equity(),     g_acct.Currency());
   s += StringFormat("Daily DD : %s"        + D, ddStr);
   s += StringFormat("Margin   : %.1f%%"    + D, g_acct.MarginLevel());
   s += hr;

   if(HasPosition())
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!g_pos.SelectByIndex(i)) continue;
         if(g_pos.Symbol() != _Symbol || g_pos.Magic() != (ulong)InpMagicNumber) continue;

         string dir = (g_pos.PositionType() == POSITION_TYPE_BUY) ? "▲ BUY" : "▼ SELL";
         double pnl = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();

         s += StringFormat("Type     : %s"   + D, dir);
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
      s += "Status   : Waiting" + sessionStr + D;
      if(ArraySize(g_bufFastEMA) > 1)
      {
         s += StringFormat("FastEMA  : %.2f" + D, g_bufFastEMA[1]);
         s += StringFormat("SlowEMA  : %.2f" + D, g_bufSlowEMA[1]);
         s += StringFormat("TrndEMA  : %.2f" + D, g_bufTrendEMA[1]);
         s += StringFormat("RSI      : %.1f" + D, g_bufRSI[1]);
         s += StringFormat("ADX      : %.1f%s" + D, g_bufADX[1],
                           g_bufADX[1] < InpADXMinLevel ? " ◄ CHOPPY" : " ◄ TREND OK");
      }
   }
   s += hr;
   s += StringFormat("EMA  : %d/%d/%d  ADX>%.0f" + D,
                     InpFastEMA, InpSlowEMA, InpTrendEMA, InpADXMinLevel);
   s += StringFormat("Risk : %.1f%%  RR:1:%.1f  SL:%.1fxATR" + D,
                     InpRiskPercent, InpRiskReward, InpATRMultSL);
   s += StringFormat("Trail: %s  Session: %02d–%02d" + D,
                     InpUseTrailing ? "ON" : "OFF", InpSessionStart, InpSessionEnd);

   Comment(s);
}
//+------------------------------------------------------------------+
