//+------------------------------------------------------------------+
//|            GrowthMonster_XAU_HFT_v1.mq5                         |
//|   High Frequency Adaptive Growth Engine – XAUUSD Only          |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

//================ INPUT =================//
input double BaseRiskPercent = 2.0;
input double MaxDrawdownPercent = 20.0;
input int    MagicNumber = 999111;

input bool   UseNewsFilter = true;
input int    NewsBlockMinutesBefore = 15;
input int    NewsBlockMinutesAfter  = 15;
input string NewsTimes = "14:30;16:00"; // Manual input (UTC)

input bool UseBreakoutMode = true;
input bool UseMTFConfirm   = true;

input ENUM_TIMEFRAMES HigherTF = PERIOD_M15;

input int EMAFast=9, EMASlow=21, EMATrend=200;
input int ATRPeriod=14;
input int ADXPeriod=14;

input double TrailATR = 1.2;

//========================================//

int hEmaFast,hEmaSlow,hEmaTrend,hATR,hADX;
int hHTFTrend;

double peakEquity=0;
bool partialClosed=false;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);

   hEmaFast  = iMA(_Symbol,_Period,EMAFast,0,MODE_EMA,PRICE_CLOSE);
   hEmaSlow  = iMA(_Symbol,_Period,EMASlow,0,MODE_EMA,PRICE_CLOSE);
   hEmaTrend = iMA(_Symbol,_Period,EMATrend,0,MODE_EMA,PRICE_CLOSE);
   hATR      = iATR(_Symbol,_Period,ATRPeriod);
   hADX      = iADX(_Symbol,_Period,ADXPeriod);

   hHTFTrend = iMA(_Symbol,HigherTF,EMATrend,0,MODE_EMA,PRICE_CLOSE);

   peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
double DynamicRisk()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > peakEquity)
      peakEquity = equity;

   double dd = (peakEquity-equity)/peakEquity*100.0;

   if(dd > 10)
      return BaseRiskPercent * 0.5;

   return BaseRiskPercent;
}
//+------------------------------------------------------------------+
double CalcLot(double sl_points)
{
   double riskPercent = DynamicRisk();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * riskPercent/100.0;

   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double point     = SymbolInfoDouble(_Symbol,SYMBOL_POINT);

   double lot = riskMoney/(sl_points*point*tickValue);

   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);

   lot = MathFloor(lot/step)*step;
   lot = MathMax(minLot,MathMin(maxLot,lot));

   return lot;
}
//+------------------------------------------------------------------+
bool NewsBlocked()
{
   if(!UseNewsFilter) return false;

   string arr[];
   int total = StringSplit(NewsTimes,';',arr);

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);

   for(int i=0;i<total;i++)
   {
      string t = arr[i];
      int hour = (int)StringToInteger(StringSubstr(t,0,2));
      int min  = (int)StringToInteger(StringSubstr(t,3,2));

      datetime newsTime = StructToTime(dt);
      newsTime = newsTime - dt.hour*3600 - dt.min*60 + hour*3600 + min*60;

      if(MathAbs(TimeCurrent()-newsTime) <= NewsBlockMinutesBefore*60)
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
bool MTFBiasBuy()
{
   if(!UseMTFConfirm) return true;

   double trend[];
   ArraySetAsSeries(trend,true);
   if(CopyBuffer(hHTFTrend,0,0,1,trend)<1) return false;

   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   return price > trend[0];
}
//+------------------------------------------------------------------+
bool MTFBiasSell()
{
   if(!UseMTFConfirm) return true;

   double trend[];
   ArraySetAsSeries(trend,true);
   if(CopyBuffer(hHTFTrend,0,0,1,trend)<1) return false;

   double price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   return price < trend[0];
}
//+------------------------------------------------------------------+
void PartialCloseManager()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!PositionSelectByIndex(i)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;

      ulong ticket=PositionGetInteger(POSITION_TICKET);
      double open =PositionGetDouble(POSITION_PRICE_OPEN);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double sl   =PositionGetDouble(POSITION_SL);
      double tp   =PositionGetDouble(POSITION_TP);

      double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      double bid  =SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask  =SymbolInfoDouble(_Symbol,SYMBOL_ASK);

      double risk = MathAbs(open-sl);
      if(risk<=0) continue;

      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
      {
         if(!partialClosed && bid-open >= risk)
         {
            trade.PositionClosePartial(ticket,volume*0.5);
            trade.PositionModify(ticket,open,tp);
            partialClosed=true;
         }
      }
      else
      {
         if(!partialClosed && open-ask >= risk)
         {
            trade.PositionClosePartial(ticket,volume*0.5);
            trade.PositionModify(ticket,open,tp);
            partialClosed=true;
         }
      }
   }
}
//+------------------------------------------------------------------+
void TrailingManager()
{
   double atr[];
   ArraySetAsSeries(atr,true);
   if(CopyBuffer(hATR,0,0,1,atr)<1) return;

   double trail = atr[0]*TrailATR;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!PositionSelectByIndex(i)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;

      ulong ticket=PositionGetInteger(POSITION_TICKET);
      double sl=PositionGetDouble(POSITION_SL);

      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
      {
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double newSL=bid-trail;
         if(newSL>sl)
            trade.PositionModify(ticket,newSL,PositionGetDouble(POSITION_TP));
      }
      else
      {
         double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double newSL=ask+trail;
         if(newSL<sl || sl==0)
            trade.PositionModify(ticket,newSL,PositionGetDouble(POSITION_TP));
      }
   }
}
//+------------------------------------------------------------------+
void EntryEngine()
{
   if(NewsBlocked()) return;

   double emaFast[2],emaSlow[2],emaTrend[1],atr[1],adx[1];

   ArraySetAsSeries(emaFast,true);
   ArraySetAsSeries(emaSlow,true);

   if(CopyBuffer(hEmaFast,0,0,2,emaFast)<2) return;
   if(CopyBuffer(hEmaSlow,0,0,2,emaSlow)<2) return;
   if(CopyBuffer(hEmaTrend,0,0,1,emaTrend)<1) return;
   if(CopyBuffer(hATR,0,0,1,atr)<1) return;
   if(CopyBuffer(hADX,0,0,1,adx)<1) return;

   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double sl_points=(atr[0]*1.1)/point;
   double tp_points=(atr[0]*2.5)/point;

   if(UseBreakoutMode && adx[0]>20)
   {
      MqlRates r[];
      ArraySetAsSeries(r,true);
      if(CopyRates(_Symbol,_Period,0,2,r)<2) return;

      if(r[0].high-r[0].low > atr[0])
      {
         if(MTFBiasBuy())
         {
            double lot=CalcLot(sl_points);
            double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            trade.Buy(lot,_Symbol,ask,
                      ask-sl_points*point,
                      ask+tp_points*point,
                      "BreakoutBuy");
         }
      }
   }

   if(emaFast[1]<emaSlow[1] && emaFast[0]>emaSlow[0] && MTFBiasBuy())
   {
      double lot=CalcLot(sl_points);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      trade.Buy(lot,_Symbol,ask,
                ask-sl_points*point,
                ask+tp_points*point,
                "MomentumBuy");
   }

   if(emaFast[1]>emaSlow[1] && emaFast[0]<emaSlow[0] && MTFBiasSell())
   {
      double lot=CalcLot(sl_points);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      trade.Sell(lot,_Symbol,bid,
                 bid+sl_points*point,
                 bid-tp_points*point,
                 "MomentumSell");
   }
}
//+------------------------------------------------------------------+
void OnTick()
{
   PartialCloseManager();
   TrailingManager();
   EntryEngine();
}
//+------------------------------------------------------------------+
