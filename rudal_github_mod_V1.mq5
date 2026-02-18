//+------------------------------------------------------------------+
//|                 XAUUSD PRO SMART EA v1.00                       |
//|                 Optimized for M1 & M5                            |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//================ INPUT PARAMETERS =================//

input group "=== GENERAL SETTINGS ==="
input ulong   MagicNumber = 20260218;
input ENUM_TIMEFRAMES TradeTF = PERIOD_M1;

input group "=== SESSION FILTER (SERVER TIME) ==="
input int StartHour = 1;
input int EndHour   = 23;

input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 1.0;
input double MaxDailyDrawdownPercent = 5.0;
input int    MaxTradesPerDay = 3;

input group "=== TREND FILTER ==="
input int EMA_Fast = 9;
input int EMA_Mid  = 21;
input int EMA_Slow = 200;

input group "=== VOLATILITY FILTER ==="
input int ATR_Period = 14;
input double ATR_MinPoints = 150;

input group "=== SL TP SETTINGS (ATR BASED) ==="
input double SL_ATR_Multiplier = 1.5;
input double TP_ATR_Multiplier = 3.0;

input group "=== TRAILING SETTINGS ==="
input bool EnableTrailing = true;
input double Trail_ATR_Multiplier = 1.0;

input group "=== BREAKEVEN SETTINGS ==="
input bool EnableBreakEven = true;
input double BE_ATR_Multiplier = 1.0;

input group "=== SPREAD FILTER ==="
input double MaxSpreadPoints = 300;

//================ GLOBAL VARIABLES =================//

int emaFastHandle, emaMidHandle, emaSlowHandle, atrHandle;
double initialBalance;
int tradesToday = 0;
datetime lastTradeDay = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   emaFastHandle = iMA(_Symbol,TradeTF,EMA_Fast,0,MODE_EMA,PRICE_CLOSE);
   emaMidHandle  = iMA(_Symbol,TradeTF,EMA_Mid,0,MODE_EMA,PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol,TradeTF,EMA_Slow,0,MODE_EMA,PRICE_CLOSE);
   atrHandle     = iATR(_Symbol,TradeTF,ATR_Period);

   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+

void OnTick()
{
   if(!IsNewCandle()) return;

   ResetDailyCounter();
   if(!SessionAllowed()) return;
   if(!SpreadAllowed()) return;
   if(!DrawdownAllowed()) return;
   if(tradesToday >= MaxTradesPerDay) return;
   if(PositionExists()) return;
   if(!ATRFilter()) return;

   TradeLogic();
   ManagePositions();
}

//+------------------------------------------------------------------+
// NEW CANDLE
bool IsNewCandle()
{
   static datetime lastBar=0;
   datetime currentBar = iTime(_Symbol,TradeTF,0);
   if(currentBar!=lastBar)
   {
      lastBar=currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// SESSION FILTER
bool SessionAllowed()
{
   int hour = TimeHour(TimeCurrent());
   if(hour>=StartHour && hour<=EndHour)
      return true;
   return false;
}

//+------------------------------------------------------------------+
// SPREAD FILTER
bool SpreadAllowed()
{
   double spread = (SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                   -SymbolInfoDouble(_Symbol,SYMBOL_BID))
                   /_Point;

   if(spread <= MaxSpreadPoints)
      return true;
   return false;
}

//+------------------------------------------------------------------+
// DRAWDOWN CONTROL
bool DrawdownAllowed()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = 100.0*(initialBalance-equity)/initialBalance;
   if(dd>=MaxDailyDrawdownPercent)
      return false;
   return true;
}

//+------------------------------------------------------------------+
// DAILY RESET
void ResetDailyCounter()
{
   datetime currentDay = Date();
   if(currentDay!=lastTradeDay)
   {
      tradesToday=0;
      lastTradeDay=currentDay;
      initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

//+------------------------------------------------------------------+
// POSITION CHECK
bool PositionExists()
{
   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetSymbol(i)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==MagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// ATR FILTER
bool ATRFilter()
{
   double atr[];
   CopyBuffer(atrHandle,0,0,1,atr);
   if(atr[0]/_Point >= ATR_MinPoints)
      return true;
   return false;
}

//+------------------------------------------------------------------+
// LOT CALCULATION
double CalculateLot(double slPoints)
{
   double riskMoney = AccountBalance()*RiskPercent/100.0;
   double lot = riskMoney/(slPoints*_Point*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE));
   return NormalizeDouble(lot,2);
}

//+------------------------------------------------------------------+
// MAIN LOGIC
void TradeLogic()
{
   double emaFast[], emaMid[], emaSlow[], atr[];
   CopyBuffer(emaFastHandle,0,0,2,emaFast);
   CopyBuffer(emaMidHandle,0,0,2,emaMid);
   CopyBuffer(emaSlowHandle,0,0,2,emaSlow);
   CopyBuffer(atrHandle,0,0,1,atr);

   double slPoints = atr[0]/_Point * SL_ATR_Multiplier;
   double tpPoints = atr[0]/_Point * TP_ATR_Multiplier;

   double lot = CalculateLot(slPoints);

   double close1 = iClose(_Symbol,TradeTF,1);

   // BUY CONDITION
   if(close1 > emaSlow[0] && emaFast[0]>emaMid[0])
   {
      trade.SetExpertMagicNumber(MagicNumber);
      trade.Buy(lot,_Symbol,0,
                SymbolInfoDouble(_Symbol,SYMBOL_BID)-slPoints*_Point,
                SymbolInfoDouble(_Symbol,SYMBOL_BID)+tpPoints*_Point);
      tradesToday++;
   }

   // SELL CONDITION
   if(close1 < emaSlow[0] && emaFast[0]<emaMid[0])
   {
      trade.SetExpertMagicNumber(MagicNumber);
      trade.Sell(lot,_Symbol,0,
                 SymbolInfoDouble(_Symbol,SYMBOL_ASK)+slPoints*_Point,
                 SymbolInfoDouble(_Symbol,SYMBOL_ASK)-tpPoints*_Point);
      tradesToday++;
   }
}

//+------------------------------------------------------------------+
// POSITION MANAGEMENT
void ManagePositions()
{
   if(!PositionExists()) return;

   double atr[];
   CopyBuffer(atrHandle,0,0,1,atr);
   double atrPoints = atr[0]/_Point;

   for(int i=0;i<PositionsTotal();i++)
   {
      if(PositionGetSymbol(i)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;

      ulong ticket = PositionGetTicket(i);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);

      // BREAKEVEN
      if(EnableBreakEven)
      {
         if(MathAbs(price-openPrice)/_Point >= atrPoints*BE_ATR_Multiplier)
            trade.PositionModify(ticket,openPrice,PositionGetDouble(POSITION_TP));
      }

      // TRAILING
      if(EnableTrailing)
      {
         double newSL = price - atrPoints*Trail_ATR_Multiplier*_Point;
         if(newSL > sl)
            trade.PositionModify(ticket,newSL,PositionGetDouble(POSITION_TP));
      }
   }
}
//+------------------------------------------------------------------+
