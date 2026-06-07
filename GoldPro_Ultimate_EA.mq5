//+------------------------------------------------------------------+
//|                                        GoldPro_Ultimate_EA.mq5  |
//|                        Breakout Strategy for XAUUSD - H1        |
//|                                              Version 1.00        |
//+------------------------------------------------------------------+
#property copyright   "GoldPro Ultimate EA"
#property link        ""
#property version     "1.00"
#property description "H1 Breakout EA for XAUUSD with ATR risk management"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group            "=== Strategy Settings ==="
input int              InpBreakoutPeriod    = 20;       // BreakoutPeriod: lookback candles (H1)
input int              InpATR_Period        = 14;       // ATR_Period: ATR calculation period

input group            "=== Risk Management ==="
input double           InpATR_SL_Multiplier = 1.5;     // ATR_SL_Multiplier: SL = ATR * this
input double           InpRiskRewardRatio   = 2.0;     // RiskRewardRatio: TP = SL * this
input double           InpRiskPercent       = 1.5;     // RiskPercent: % of balance per trade
input double           InpMaxLotSize        = 5.0;     // MaxLotSize: hard cap on lot size

input group            "=== EA Settings ==="
input long             InpMagicNumber       = 123456;  // MagicNumber: unique EA identifier

//+------------------------------------------------------------------+
//| Global Objects                                                   |
//+------------------------------------------------------------------+
CTrade        g_trade;
CPositionInfo g_pos;
CSymbolInfo   g_sym;

//--- Indicator handle
int    g_atrHandle  = INVALID_HANDLE;
double g_atrBuf[];

//--- Cached levels (refreshed every tick)
double g_chanHigh   = 0.0;
double g_chanLow    = 0.0;
double g_atrVal     = 0.0;

//--- One-trade-per-bar guard
datetime g_lastTradeBar = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate all inputs up-front
   if(InpBreakoutPeriod    < 2  ||
      InpATR_Period         < 1  ||
      InpATR_SL_Multiplier <= 0  ||
      InpRiskRewardRatio   <= 0  ||
      InpRiskPercent       <= 0  ||
      InpMaxLotSize        <= 0)
   {
      Print("ERROR: One or more input parameters are invalid. EA stopped.");
      return INIT_PARAMETERS_INCORRECT;
   }

   //--- Configure trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);          // 3 pip slippage tolerance
   g_trade.SetTypeFilling(DetectFillMode());  // auto-detect FOK/IOC/RETURN
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   //--- Initialize symbol info
   if(!g_sym.Name(Symbol()))
   {
      Print("ERROR: Failed to initialize symbol info for ", Symbol());
      return INIT_FAILED;
   }
   g_sym.Refresh();

   //--- Create ATR indicator (forced to H1 regardless of chart TF)
   g_atrHandle = iATR(Symbol(), PERIOD_H1, InpATR_Period);
   if(g_atrHandle == INVALID_HANDLE)
   {
      PrintFormat("ERROR: iATR creation failed. Code=%d", GetLastError());
      return INIT_FAILED;
   }
   ArraySetAsSeries(g_atrBuf, true);

   //--- Startup log
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   Print("      GoldPro Ultimate EA v1.00  |  STARTED");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   PrintFormat("  Symbol    : %s", Symbol());
   PrintFormat("  Magic     : %d", InpMagicNumber);
   PrintFormat("  Breakout  : %d bars (H1)", InpBreakoutPeriod);
   PrintFormat("  ATR Period: %d", InpATR_Period);
   PrintFormat("  SL Mult   : %.2f  |  RR Ratio: %.2f", InpATR_SL_Multiplier, InpRiskRewardRatio);
   PrintFormat("  Risk      : %.2f%%  |  MaxLot : %.2f", InpRiskPercent, InpMaxLotSize);
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   Comment("");
   PrintFormat("GoldPro EA deinitialized. Reason=%d", reason);
}

//+------------------------------------------------------------------+
//| Main tick handler                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Always refresh prices first
   if(!g_sym.RefreshRates()) return;

   //--- Get current H1 bar open time (works on any chart timeframe)
   datetime barTime = iTime(Symbol(), PERIOD_H1, 0);
   if(barTime == 0) return;

   //--- Refresh indicator values; abort tick if data unavailable
   if(!RefreshLevels()) return;

   //--- Update the chart overlay
   DrawComment(barTime);

   //--- ── One trade per H1 bar ──
   if(g_lastTradeBar == barTime) return;

   //--- ── No stacking positions ──
   if(HasPosition()) return;

   //--- Basic sanity checks on cached values
   double ask = g_sym.Ask();
   double bid = g_sym.Bid();
   if(ask <= 0.0 || bid <= 0.0) return;
   if(g_atrVal <= 0.0 || g_chanHigh <= 0.0 || g_chanLow <= 0.0) return;

   //--- SL / TP distances
   double slDist = g_atrVal * InpATR_SL_Multiplier;
   double tpDist = slDist   * InpRiskRewardRatio;

   //--- Enforce broker minimum stop distance
   double minStop = (double)g_sym.StopsLevel() * g_sym.Point();
   if(slDist < minStop)
   {
      slDist = minStop;
      tpDist = slDist * InpRiskRewardRatio;
      PrintFormat("INFO: SL adjusted to broker minimum: %.5f", slDist);
   }

   //--- ── BUY: Ask breaks above the channel high ──
   if(ask > g_chanHigh)
   {
      double sl  = NormalizeDouble(ask - slDist, _Digits);
      double tp  = NormalizeDouble(ask + tpDist, _Digits);
      double lot = CalcLot(slDist);

      if(lot <= 0.0) return;
      if(!SufficientMargin(ORDER_TYPE_BUY, lot, ask)) return;

      PrintFormat("▶ BUY SIGNAL | Ask=%.2f | ChanH=%.2f | ATR=%.2f | SL=%.2f | TP=%.2f | Lot=%.2f",
                  ask, g_chanHigh, g_atrVal, sl, tp, lot);

      if(g_trade.Buy(lot, Symbol(), ask, sl, tp, "GoldPro_B"))
      {
         g_lastTradeBar = barTime;
         PrintFormat("  ✓ BUY #%d opened  Lot=%.2f  SL=%.2f  TP=%.2f",
                     g_trade.ResultOrder(), lot, sl, tp);
      }
      else
         PrintFormat("  ✗ BUY failed  Err=%d  %s",
                     g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   }
   //--- ── SELL: Bid breaks below the channel low ──
   else if(bid < g_chanLow)
   {
      double sl  = NormalizeDouble(bid + slDist, _Digits);
      double tp  = NormalizeDouble(bid - tpDist, _Digits);
      double lot = CalcLot(slDist);

      if(lot <= 0.0) return;
      if(!SufficientMargin(ORDER_TYPE_SELL, lot, bid)) return;

      PrintFormat("▼ SELL SIGNAL | Bid=%.2f | ChanL=%.2f | ATR=%.2f | SL=%.2f | TP=%.2f | Lot=%.2f",
                  bid, g_chanLow, g_atrVal, sl, tp, lot);

      if(g_trade.Sell(lot, Symbol(), bid, sl, tp, "GoldPro_S"))
      {
         g_lastTradeBar = barTime;
         PrintFormat("  ✓ SELL #%d opened  Lot=%.2f  SL=%.2f  TP=%.2f",
                     g_trade.ResultOrder(), lot, sl, tp);
      }
      else
         PrintFormat("  ✗ SELL failed  Err=%d  %s",
                     g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Refresh ATR, channel high/low from last N closed H1 bars        |
//+------------------------------------------------------------------+
bool RefreshLevels()
{
   //--- ATR from bar index 1 (last fully closed bar)
   if(CopyBuffer(g_atrHandle, 0, 1, 1, g_atrBuf) < 1)
   {
      Print("WARNING: ATR buffer copy failed.");
      return false;
   }
   g_atrVal = g_atrBuf[0];

   //--- High / Low of last N closed H1 bars (exclude bar 0 = forming)
   double hiArr[], loArr[];
   ArraySetAsSeries(hiArr, true);
   ArraySetAsSeries(loArr, true);

   if(CopyHigh(Symbol(), PERIOD_H1, 1, InpBreakoutPeriod, hiArr) < InpBreakoutPeriod)
   {
      Print("WARNING: CopyHigh failed.");
      return false;
   }
   if(CopyLow(Symbol(), PERIOD_H1, 1, InpBreakoutPeriod, loArr) < InpBreakoutPeriod)
   {
      Print("WARNING: CopyLow failed.");
      return false;
   }

   g_chanHigh = hiArr[ArrayMaximum(hiArr, 0, InpBreakoutPeriod)];
   g_chanLow  = loArr[ArrayMinimum(loArr, 0, InpBreakoutPeriod)];
   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size based on % risk and ATR stop distance   |
//+------------------------------------------------------------------+
double CalcLot(double slDist)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt = balance * InpRiskPercent / 100.0;

   double tickVal = g_sym.TickValue();   // account currency per tick per 1 lot
   double tickSz  = g_sym.TickSize();   // smallest price movement

   if(tickSz <= 0.0 || tickVal <= 0.0)
   {
      Print("ERROR: Invalid tick data – TickValue=", tickVal, "  TickSize=", tickSz);
      return 0.0;
   }

   // lot = riskAmount / (SL_in_ticks * tickValue_per_lot)
   double lot = riskAmt / ((slDist / tickSz) * tickVal);

   double step = g_sym.LotsStep();
   double minL = g_sym.LotsMin();
   double maxL = MathMin(g_sym.LotsMax(), InpMaxLotSize);

   lot = MathFloor(lot / step) * step;   // round down to nearest step

   if(lot < minL)
   {
      PrintFormat("WARNING: Calculated lot %.4f < minLot %.4f – trade skipped.", lot, minL);
      return 0.0;
   }
   lot = MathMin(lot, maxL);
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Check if free margin is sufficient before sending order         |
//+------------------------------------------------------------------+
bool SufficientMargin(ENUM_ORDER_TYPE type, double lot, double price)
{
   double margin = 0.0;
   if(!OrderCalcMargin(type, Symbol(), lot, price, margin))
   {
      PrintFormat("ERROR: OrderCalcMargin failed. Err=%d", GetLastError());
      return false;
   }
   double freeMgn = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(margin > freeMgn * 0.9)
   {
      PrintFormat("WARNING: Need $%.2f margin but only $%.2f free (90%% cap). Trade skipped.",
                  margin, freeMgn);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Return true if this EA already has an open position             |
//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_pos.SelectByIndex(i)              &&
         g_pos.Symbol() == Symbol()          &&
         g_pos.Magic()  == InpMagicNumber)
         return true;
   return false;
}

//+------------------------------------------------------------------+
//| Auto-detect the order filling mode supported by broker/symbol   |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING DetectFillMode()
{
   uint modes = (uint)SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
   if((modes & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((modes & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Draw chart overlay with live EA status                          |
//+------------------------------------------------------------------+
void DrawComment(datetime barTime)
{
   //--- Count open positions and sum floating P/L
   int    cnt = 0;
   double fpl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(g_pos.SelectByIndex(i) && g_pos.Symbol() == Symbol() && g_pos.Magic() == InpMagicNumber)
         { cnt++; fpl += g_pos.Profit(); }

   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double equ   = AccountInfoDouble(ACCOUNT_EQUITY);
   double fmgn  = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double drawdown = (bal > 0) ? (bal - equ) / bal * 100.0 : 0.0;

   string c = "";
   c += "╔══════════════════════════════════╗\n";
   c += "║     GoldPro Ultimate EA  v1.00   ║\n";
   c += "╠══════════════════════════════════╣\n";
   c += StringFormat("║  Balance   : $%12.2f       ║\n", bal);
   c += StringFormat("║  Equity    : $%12.2f       ║\n", equ);
   c += StringFormat("║  Free Mgn  : $%12.2f       ║\n", fmgn);
   c += StringFormat("║  Drawdown  :  %11.2f %%      ║\n", drawdown);
   c += "╠══════════════════════════════════╣\n";
   c += StringFormat("║  Chan High : %14.2f       ║\n", g_chanHigh);
   c += StringFormat("║  Chan Low  : %14.2f       ║\n", g_chanLow);
   c += StringFormat("║  ATR(%2d)   : %14.5f       ║\n", InpATR_Period, g_atrVal);
   c += StringFormat("║  SL Dist   : %14.5f       ║\n", g_atrVal * InpATR_SL_Multiplier);
   c += "╠══════════════════════════════════╣\n";
   c += StringFormat("║  Positions : %2d                     ║\n", cnt);
   c += StringFormat("║  Float P/L : $%12.2f       ║\n", fpl);
   c += StringFormat("║  Bar Traded: %-5s                ║\n", (g_lastTradeBar == barTime ? "YES" : "NO"));
   c += "╚══════════════════════════════════╝";

   Comment(c);
}
//+------------------------------------------------------------------+
