//+------------------------------------------------------------------+
//|                                         GoldPro_H1_EA.mq5        |
//|                     Professional XAUUSD H1 Expert Advisor        |
//|         Strategy: EMA Crossover + RSI + ADX + ATR Risk Mgmt      |
//+------------------------------------------------------------------+
#property copyright   "GoldPro EA v1.00"
#property version     "1.00"
#property description "XAUUSD H1 EA — EMA(21/50/200) + RSI(14) + ADX(14) + ATR Risk Management"

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
input double InpRSIOverbought = 70.0;  // RSI Overbought Level (filter sells above this)
input double InpRSIOversold   = 30.0;  // RSI Oversold Level  (filter buys below this)
input int    InpADXPeriod     = 14;    // ADX Period
input double InpADXMinLevel   = 20.0;  // ADX Minimum (skip trades in choppy markets)
input int    InpATRPeriod     = 14;    // ATR Period

input group "─── Risk Management ────────────────────────"
input double InpRiskPercent   = 1.0;   // Risk Per Trade (% of Balance)
input double InpATRMultSL     = 1.5;   // ATR Multiplier for Stop Loss
input double InpRiskReward    = 2.0;   // Risk:Reward Ratio (1 : X)
input bool   InpUseTrailing   = true;  // Enable ATR Trailing Stop
input double InpTrailATRMult  = 1.0;   // ATR Multiplier for Trailing Stop
input double InpMinBalance    = 100.0; // Minimum Balance Required ($)

input group "─── Trade Settings ─────────────────────────"
input int    InpMagicNumber   = 20240101;    // Magic Number
input int    InpSlippage      = 15;          // Max Slippage (points)
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

datetime g_lastBarTime = 0;

//==========================================================================
//  OnInit
//==========================================================================
int OnInit()
{
   //--- Parameter sanity checks
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
      Print("ERROR: RiskPercent must be 0.01–10.0. Got: ", InpRiskPercent);
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

   //--- Create indicator handles on H1 regardless of chart timeframe
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

   //--- Set buffers as time-series (index 0 = most recent)
   ArraySetAsSeries(g_bufFastEMA,  true);
   ArraySetAsSeries(g_bufSlowEMA,  true);
   ArraySetAsSeries(g_bufTrendEMA, true);
   ArraySetAsSeries(g_bufRSI,      true);
   ArraySetAsSeries(g_bufADX,      true);
   ArraySetAsSeries(g_bufATR,      true);

   PrintFormat("══════════════════════════════════════════════════");
   PrintFormat("  GoldPro H1 EA v1.00 — Initialized Successfully");
   PrintFormat("  Symbol : %s  |  Timeframe : H1", _Symbol);
   PrintFormat("  EMA    : %d / %d / %d", InpFastEMA, InpSlowEMA, InpTrendEMA);
   PrintFormat("  RSI    : %d  (OB=%.0f / OS=%.0f)", InpRSIPeriod, InpRSIOverbought, InpRSIOversold);
   PrintFormat("  ADX    : %d  (Min=%.0f)", InpADXPeriod, InpADXMinLevel);
   PrintFormat("  ATR    : %d  (SL=%.1fx, Trail=%.1fx)", InpATRPeriod, InpATRMultSL, InpTrailATRMult);
   PrintFormat("  Risk   : %.1f%%  |  RR: 1:%.1f  |  Trailing: %s",
               InpRiskPercent, InpRiskReward, InpUseTrailing ? "ON" : "OFF");
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
   PrintFormat("GoldPro EA stopped. Reason code: %d", reason);
}

//==========================================================================
//  OnTick  — main loop
//==========================================================================
void OnTick()
{
   //--- Always: update trailing stop on every tick
   if(InpUseTrailing && HasPosition())
      ApplyTrailing();

   //--- Always: refresh chart overlay
   RefreshChart();

   //--- Process signals only on new H1 bar close
   datetime barTime = iTime(_Symbol, PERIOD_H1, 0);
   if(barTime == g_lastBarTime) return;
   g_lastBarTime = barTime;

   //--- Load all indicator buffers
   if(!LoadBuffers()) return;

   //--- Only one position at a time
   if(HasPosition())
   {
      PrintFormat("[%s] Position open — waiting for close/TP/SL",
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      return;
   }

   //--- Minimum balance guard
   if(g_acct.Balance() < InpMinBalance)
   {
      PrintFormat("[%s] SKIP — Balance %.2f < MinBalance %.2f",
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                  g_acct.Balance(), InpMinBalance);
      return;
   }

   //--- Evaluate and act on signal
   int sig = GetSignal();
   if(sig ==  1) ExecuteBuy();
   if(sig == -1) ExecuteSell();
}

//==========================================================================
//  LoadBuffers — copy indicator data (4 bars is enough for crossover)
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
//  GetSignal — returns 1=Buy, -1=Sell, 0=No Signal
//
//  Logic:
//    1. ADX > threshold → confirmed trending market
//    2. EMA(Fast) crosses EMA(Slow) on last closed bar
//    3. Price AND Fast EMA both on correct side of EMA(200) → trend alignment
//    4. RSI confirms momentum without being at extreme
//==========================================================================
int GetSignal()
{
   //--- Last closed bar = index 1; bar before = index 2
   double fastNow   = g_bufFastEMA[1],  fastPrev  = g_bufFastEMA[2];
   double slowNow   = g_bufSlowEMA[1],  slowPrev  = g_bufSlowEMA[2];
   double trendNow  = g_bufTrendEMA[1];
   double rsiNow    = g_bufRSI[1];
   double adxNow    = g_bufADX[1];
   double close1    = iClose(_Symbol, PERIOD_H1, 1);

   //--- 1. ADX filter: skip choppy/ranging markets
   if(adxNow < InpADXMinLevel)
      return 0;

   //--- 2. EMA crossover detection
   bool bullCross = (fastPrev <= slowPrev) && (fastNow > slowNow);
   bool bearCross = (fastPrev >= slowPrev) && (fastNow < slowNow);

   //--- 3. Trend alignment via 200 EMA
   bool uptrend   = (close1 > trendNow) && (fastNow > trendNow);
   bool downtrend = (close1 < trendNow) && (fastNow < trendNow);

   //--- 4. RSI: confirm momentum, reject extreme zones
   bool rsiBuy    = (rsiNow >= 45.0) && (rsiNow < InpRSIOverbought);
   bool rsiSell   = (rsiNow <= 55.0) && (rsiNow > InpRSIOversold);

   if(bullCross && uptrend && rsiBuy)
   {
      PrintFormat("[BUY SIGNAL] Bar=%s | FastEMA=%.2f > SlowEMA=%.2f | Trend=%.2f | RSI=%.1f | ADX=%.1f",
                  TimeToString(iTime(_Symbol, PERIOD_H1, 1), TIME_DATE|TIME_MINUTES),
                  fastNow, slowNow, trendNow, rsiNow, adxNow);
      return 1;
   }

   if(bearCross && downtrend && rsiSell)
   {
      PrintFormat("[SELL SIGNAL] Bar=%s | FastEMA=%.2f < SlowEMA=%.2f | Trend=%.2f | RSI=%.1f | ADX=%.1f",
                  TimeToString(iTime(_Symbol, PERIOD_H1, 1), TIME_DATE|TIME_MINUTES),
                  fastNow, slowNow, trendNow, rsiNow, adxNow);
      return -1;
   }

   return 0;
}

//==========================================================================
//  CalcLots — risk-based position sizing
//  Formula: lots = (balance × risk%) / (SL_distance_in_price × tickValue/tickSize)
//==========================================================================
double CalcLots(double slDist)
{
   if(slDist <= 0.0)
   {
      Print("ERROR: CalcLots — invalid slDist=", slDist);
      return 0.0;
   }

   double riskAmt   = g_acct.Balance() * InpRiskPercent / 100.0;
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSz <= 0.0 || tickVal <= 0.0)
   {
      Print("ERROR: CalcLots — invalid tick data. TickVal=", tickVal, " TickSz=", tickSz);
      return 0.0;
   }

   //--- USD loss per 1 lot if price moves slDist against us
   double lossPerLot = (slDist / tickSz) * tickVal;
   if(lossPerLot <= 0.0) return 0.0;

   double lots    = riskAmt / lossPerLot;
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   lots = MathFloor(lots / step) * step;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   PrintFormat("[LOTS] Balance=%.2f | Risk=%.2f$ | SL=%.4f | LossPerLot=%.2f | Lots=%.2f",
               g_acct.Balance(), riskAmt, slDist, lossPerLot, lots);
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

   if(lots <= 0.0)          { Print("ERROR: ExecuteBuy — lot calc failed"); return; }
   if(!CheckMargin(ORDER_TYPE_BUY, lots, ask)) return;

   PrintFormat("[BUY ORDER] Ask=%.2f | SL=%.2f (-%.2f) | TP=%.2f (+%.2f) | Lots=%.2f | ATR=%.2f",
               ask, sl, slD, tp, tpD, lots, atr);

   if(g_trade.Buy(lots, _Symbol, ask, sl, tp, InpComment))
      PrintFormat("[SUCCESS] BUY #%I64u opened @ %.2f", g_trade.ResultOrder(), g_trade.ResultPrice());
   else
      PrintFormat("[ERROR] BUY failed — RetCode=%d : %s",
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
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

   if(lots <= 0.0)           { Print("ERROR: ExecuteSell — lot calc failed"); return; }
   if(!CheckMargin(ORDER_TYPE_SELL, lots, bid)) return;

   PrintFormat("[SELL ORDER] Bid=%.2f | SL=%.2f (+%.2f) | TP=%.2f (-%.2f) | Lots=%.2f | ATR=%.2f",
               bid, sl, slD, tp, tpD, lots, atr);

   if(g_trade.Sell(lots, _Symbol, bid, sl, tp, InpComment))
      PrintFormat("[SUCCESS] SELL #%I64u opened @ %.2f", g_trade.ResultOrder(), g_trade.ResultPrice());
   else
      PrintFormat("[ERROR] SELL failed — RetCode=%d : %s",
                  g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
}

//==========================================================================
//  ApplyTrailing — ATR-based trailing stop (moves only in favorable direction)
//==========================================================================
void ApplyTrailing()
{
   if(CopyBuffer(g_hATR, 0, 0, 2, g_bufATR) < 2) return;
   double trailD = InpTrailATRMult * g_bufATR[1];
   if(trailD <= 0.0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_pos.SelectByIndex(i))                                continue;
      if(g_pos.Symbol() != _Symbol)                             continue;
      if(g_pos.Magic()  != (ulong)InpMagicNumber)               continue;

      ulong  tk   = g_pos.Ticket();
      double cSL  = g_pos.StopLoss();
      double cTP  = g_pos.TakeProfit();
      double op   = g_pos.PriceOpen();

      if(g_pos.PositionType() == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double nSL = NormalizeDouble(bid - trailD, _Digits);
         //--- Move SL up only; only after trade is in profit
         if(nSL > cSL + _Point && nSL > op)
         {
            if(g_trade.PositionModify(tk, nSL, cTP))
               PrintFormat("[TRAIL BUY]  #%I64u  SL: %.2f → %.2f  (Bid=%.2f)", tk, cSL, nSL, bid);
         }
      }
      else if(g_pos.PositionType() == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double nSL = NormalizeDouble(ask + trailD, _Digits);
         //--- Move SL down only; only after trade is in profit
         if((cSL == 0.0 || nSL < cSL - _Point) && nSL < op)
         {
            if(g_trade.PositionModify(tk, nSL, cTP))
               PrintFormat("[TRAIL SELL] #%I64u  SL: %.2f → %.2f  (Ask=%.2f)", tk, cSL, nSL, ask);
         }
      }
   }
}

//==========================================================================
//  HasPosition — checks for any open position by this EA on this symbol
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
//  CheckMargin — verifies sufficient free margin before opening
//==========================================================================
bool CheckMargin(ENUM_ORDER_TYPE type, double lots, double price)
{
   double margin;
   if(!OrderCalcMargin(type, _Symbol, lots, price, margin))
   {
      Print("ERROR: OrderCalcMargin failed");
      return false;
   }
   double freeMargin = g_acct.FreeMargin();
   if(freeMargin < margin * 1.2) // require 20% buffer above minimum
   {
      PrintFormat("WARNING: Free margin %.2f < required %.2f (×1.2 safety buffer)",
                  freeMargin, margin * 1.2);
      return false;
   }
   return true;
}

//==========================================================================
//  DetectFillingMode — returns broker-supported order filling type
//==========================================================================
ENUM_ORDER_TYPE_FILLING DetectFillingMode()
{
   int flags = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_FLAGS);
   if((flags & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((flags & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//==========================================================================
//  RefreshChart — live info overlay on the chart
//==========================================================================
void RefreshChart()
{
   string D  = "\n";
   string hr = "────────────────────────────" + D;

   string s  = hr;
   s += "   GoldPro H1 EA  v1.00" + D;
   s += hr;
   s += StringFormat("Balance  : %10.2f %s" + D, g_acct.Balance(),    g_acct.Currency());
   s += StringFormat("Equity   : %10.2f %s" + D, g_acct.Equity(),     g_acct.Currency());
   s += StringFormat("Margin   : %10.1f %%" + D, g_acct.MarginLevel());
   s += hr;

   if(HasPosition())
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!g_pos.SelectByIndex(i)) continue;
         if(g_pos.Symbol() != _Symbol || g_pos.Magic() != (ulong)InpMagicNumber) continue;

         string dir = (g_pos.PositionType() == POSITION_TYPE_BUY) ? "▲ BUY" : "▼ SELL";
         double pnl = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
         string pnlStr = StringFormat("%+.2f %s", pnl, g_acct.Currency());

         s += StringFormat("Direction: %s" + D, dir);
         s += StringFormat("Lots     : %.2f" + D,    g_pos.Volume());
         s += StringFormat("Open     : %.2f" + D,    g_pos.PriceOpen());
         s += StringFormat("Current  : %.2f" + D,    g_pos.PriceCurrent());
         s += StringFormat("SL       : %.2f" + D,    g_pos.StopLoss());
         s += StringFormat("TP       : %.2f" + D,    g_pos.TakeProfit());
         s += StringFormat("P/L      : %s"   + D,    pnlStr);
      }
   }
   else
   {
      s += "Status   : Waiting for signal..." + D;
      if(ArraySize(g_bufFastEMA) > 1)
      {
         s += StringFormat("FastEMA  : %.2f" + D, g_bufFastEMA[1]);
         s += StringFormat("SlowEMA  : %.2f" + D, g_bufSlowEMA[1]);
         s += StringFormat("TrndEMA  : %.2f" + D, g_bufTrendEMA[1]);
         s += StringFormat("RSI      : %.1f" + D, g_bufRSI[1]);
         s += StringFormat("ADX      : %.1f%s" + D,
                           g_bufADX[1],
                           g_bufADX[1] < InpADXMinLevel ? " [CHOPPY]" : " [TREND]");
      }
   }

   s += hr;
   s += StringFormat("EMA  : %d / %d / %d" + D, InpFastEMA, InpSlowEMA, InpTrendEMA);
   s += StringFormat("Risk : %.1f%%  RR: 1:%.1f  SL: %.1fx ATR" + D,
                     InpRiskPercent, InpRiskReward, InpATRMultSL);
   s += StringFormat("Trail: %s (%.1fx ATR)" + D,
                     InpUseTrailing ? "ON" : "OFF", InpTrailATRMult);

   Comment(s);
}
//+------------------------------------------------------------------+
