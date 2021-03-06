//+------------------------------------------------------------------+
//|                                                           MA.mq5 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade trade;

enum ENUM_DIRECTION{
   NONE = -1,
   UP,
   DN
};
   input int Magic = 231;
   input int periodMA1 = 60;  input int periodMA2 = 35;  input int periodMA3 = 8;   input int periodMA4 = 1;
   input int offsetMA1 = 1;   input int offsetMA2 = 3;
   
   input int TP = 500;
   input int SL = 200;

int handleMA1; //хендл старшего МА
int handleMA2; //хендл среднего МА
int handleMA3; //хендл младшего МА
int handleMA4; //хендл самого маленького МА

double bufferMA1[];  //буфер старшего МА
double bufferMA2[];  //буфер среднего МА
double bufferMA3[];  //буфер младшего МА
double bufferMA4[];  //буфер самого маленького МА

ushort mtp;

datetime time[];
double high[];
double low[];
datetime openTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
//---
   trade.SetExpertMagicNumber(Magic);
   handleMA1 = iMA(Symbol(), PERIOD_CURRENT, periodMA1, 0, MODE_SMMA, PRICE_CLOSE);
   handleMA2 = iMA(Symbol(), PERIOD_CURRENT, periodMA2, 0, MODE_SMMA, PRICE_CLOSE);
   handleMA3 = iMA(Symbol(), PERIOD_CURRENT, periodMA3, 0, MODE_SMMA, PRICE_CLOSE);
   handleMA4 = iMA(Symbol(), PERIOD_CURRENT, periodMA4, 0, MODE_SMMA, PRICE_CLOSE);
   mtp = 1;
   if(Digits() == 3 || Digits() == 5)
      mtp = 10;
//---
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
//---
   
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
//---
   CopyTime(Symbol(), PERIOD_CURRENT, 0, 1, time);
   ArraySetAsSeries(time, true);
   
   //Ищет сигнал один раз после формирования новой свечи
   if(openTime == time[0])return;
   openTime = time[0];
   
   //ENUM_DIRECTION t = Trend();
   ENUM_DIRECTION dir = NONE;//OpenedDirection();
   //if(t == UP){      
      //Ищем сигнал на покупку         
      //if(dir != t){
         if(Signal() == UP && dir != UP){
            double pr = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            double tp = TP == 0?0.0:NormalizeDouble(pr + TP * Point() * mtp, Digits());
            double sl = SL == 0?0.0:NormalizeDouble(pr - SL * Point() * mtp, Digits());
            trade.Buy(.01, Symbol(), pr, sl, tp);
         }
      //}
   //}
   //if(t == DN){      
      //Ищем сигнал на продажу
      //if(dir != t){
         if(Signal() == DN && dir != DN){
            double pr = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            double tp = TP == 0?0.0:NormalizeDouble(pr - TP * Point() * mtp, Digits());
            double sl = SL == 0?0.0:NormalizeDouble(pr + SL * Point() * mtp, Digits());
            trade.Sell(.01, Symbol(), pr, sl, tp);
         }
      //}
   //}         
}


//+------------------------------------------------------------------+
ENUM_DIRECTION OpenedDirection(){
   for(int i = PositionsTotal()-1; i >= 0; i--){
      ulong t = PositionGetTicket(i);
      bool x = PositionSelectByTicket(t);
      if(PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == Magic)
         return (ENUM_DIRECTION)PositionGetInteger(POSITION_TYPE);
      
   }
   return NONE;
}


//По трём МА
ENUM_DIRECTION Trend_(){
   CopyBuffer(handleMA1, 0, 1, 2, bufferMA1);
   CopyBuffer(handleMA2, 0, 1, 2, bufferMA2);
   CopyBuffer(handleMA3, 0, 1, 2, bufferMA3);
   
   ArraySetAsSeries(bufferMA1, true);
   ArraySetAsSeries(bufferMA2, true);
   ArraySetAsSeries(bufferMA3, true);
   
   if(bufferMA1[0] > bufferMA1[1] && bufferMA2[0] > bufferMA2[1] && bufferMA3[0] > bufferMA3[1] && 
      (NormalizeDouble(bufferMA1[0] - bufferMA1[1], Digits()) / Point()) > offsetMA1 &&
      (NormalizeDouble(bufferMA2[0] - bufferMA2[1], Digits()) / Point()) > offsetMA2)
      return UP;
   if(bufferMA1[0] < bufferMA1[1] && bufferMA2[0] < bufferMA2[1] && bufferMA3[0] < bufferMA3[1] &&
      (NormalizeDouble(bufferMA1[1] - bufferMA1[0], Digits()) / Point()) > offsetMA1 &&
      (NormalizeDouble(bufferMA2[1] - bufferMA2[0], Digits()) / Point()) > offsetMA2)
      return DN;
   
   return NONE;
}


//По двум МА (относительное расположение имеет значение и учитываются наклоны)
ENUM_DIRECTION Trend__(){
   CopyBuffer(handleMA1, 0, 1, 2, bufferMA1);
   CopyBuffer(handleMA2, 0, 1, 2, bufferMA2);
   
   ArraySetAsSeries(bufferMA1, true);
   ArraySetAsSeries(bufferMA2, true);
   
   if(bufferMA1[0] > bufferMA1[1] && bufferMA2[0] > bufferMA2[1] && bufferMA1[0] < bufferMA2[0] && bufferMA1[1] < bufferMA2[1] &&
      (NormalizeDouble(bufferMA1[0] - bufferMA1[1], Digits()) / Point()) > offsetMA1 &&
      (NormalizeDouble(bufferMA2[0] - bufferMA2[1], Digits()) / Point()) > offsetMA2)
      return UP;
   if(bufferMA1[0] < bufferMA1[1] && bufferMA2[0] < bufferMA2[1] && bufferMA1[0] > bufferMA2[0] && bufferMA1[1] > bufferMA2[1] &&
      (NormalizeDouble(bufferMA1[1] - bufferMA1[0], Digits()) / Point()) > offsetMA1 &&
      (NormalizeDouble(bufferMA2[1] - bufferMA2[0], Digits()) / Point()) > offsetMA2)
      return DN;
   
   return NONE;
}


//По двум МА (относительное расположение имеет значение. не учитываются наклоны. учитывается расстояние между МА)
ENUM_DIRECTION Trend(){
   CopyBuffer(handleMA1, 0, 1, 2, bufferMA1);
   CopyBuffer(handleMA2, 0, 1, 2, bufferMA2);
   
   ArraySetAsSeries(bufferMA1, true);
   ArraySetAsSeries(bufferMA2, true);
   
   int offs1 = 0;
   int offs2 = 0;
   if(bufferMA2[0] > bufferMA1[0]){
      offs1 = NormalizeDouble(bufferMA2[0] - bufferMA1[0], Digits()) / Point();
      offs2 = NormalizeDouble(bufferMA2[1] - bufferMA1[1], Digits()) / Point();
   }
   else if(bufferMA2[0] < bufferMA1[0]){
      offs1 = NormalizeDouble(bufferMA1[0] - bufferMA2[0], Digits()) / Point();
      offs2 = NormalizeDouble(bufferMA1[1] - bufferMA2[1], Digits()) / Point();
   }
   if(offs1 > 0 && offs2 > 0 && offs1 > offsetMA1 && offs1 >= offs2){
      if(bufferMA2[0] > bufferMA1[0]) return UP;
      if(bufferMA2[0] < bufferMA1[0]) return DN;
   }   
   return NONE;
}


//Вход по трём МА без учёта тренда. МА с периодом 1 должна быть выше двух МА (8 и 35), чтобы покупать и инже - чтобы продавать
ENUM_DIRECTION Signal(){
   CopyBuffer(handleMA4, 0, 1, 2, bufferMA4);
   CopyBuffer(handleMA2, 0, 1, 2, bufferMA2);
   CopyBuffer(handleMA3, 0, 1, 2, bufferMA3);
   
   ArraySetAsSeries(bufferMA4, true);
   ArraySetAsSeries(bufferMA2, true);
   ArraySetAsSeries(bufferMA3, true);
   
   if(bufferMA4[0] > bufferMA3[0] && bufferMA4[0] > bufferMA2[0] && bufferMA4[1] <= bufferMA2[1]) return UP;
   if(bufferMA4[0] < bufferMA3[0] && bufferMA4[0] < bufferMA2[0] && bufferMA4[1] >= bufferMA2[1]) return DN;
   return NONE;
}


//Вход после ценового касания и пробоя второй МА
ENUM_DIRECTION Signal___(ENUM_DIRECTION t){
   MqlRates rates[];
   CopyRates(Symbol(), PERIOD_CURRENT, 1, 1, rates);
   ArraySetAsSeries(rates, true);
   if(t == UP && rates[0].low < bufferMA2[0]) return UP;
   if(t == DN && rates[0].high > bufferMA2[0]) return DN;
   return NONE;
}


//Вход младшего МА в более старший (перед отскоком)
ENUM_DIRECTION Signal_(){
   CopyBuffer(handleMA3, 0, 0, 1, bufferMA3);
   CopyBuffer(handleMA4, 0, 0, 1, bufferMA4);
   
   ArraySetAsSeries(bufferMA3, true);
   ArraySetAsSeries(bufferMA4, true);
   
   if(bufferMA4[0] < bufferMA3[0]) return UP;
   if(bufferMA4[0] > bufferMA3[0]) return DN;
   
   return NONE;
}


//Пересечение выход младшего МА из следующего по величине
ENUM_DIRECTION Signal____(){
   CopyBuffer(handleMA3, 0, 1, 2, bufferMA3);
   
   ArraySetAsSeries(bufferMA3, true);
   
   if(bufferMA3[0] > bufferMA2[0] && bufferMA3[1] < bufferMA2[1]) return UP;
   if(bufferMA3[0] < bufferMA2[0] && bufferMA3[1] > bufferMA2[1]) return DN;
   
   return NONE;
}

//Пересечение выход младшего МА из следующего по величине
ENUM_DIRECTION Signal___(){
   CopyBuffer(handleMA3, 0, 1, 2, bufferMA3);
   CopyBuffer(handleMA4, 0, 1, 2, bufferMA4);
   
   ArraySetAsSeries(bufferMA3, true);
   ArraySetAsSeries(bufferMA4, true);
   
   if(bufferMA4[0] > bufferMA3[0] && bufferMA4[1] <= bufferMA3[1] && bufferMA4[0] > bufferMA4[1]) return UP;
   if(bufferMA4[0] < bufferMA3[0] && bufferMA4[1] >= bufferMA3[1] && bufferMA4[0] < bufferMA4[1]) return DN;
   
   return NONE;
}


//направление младшего МА по двум точкам (в направлении тренда)
ENUM_DIRECTION Signal_____(){
   CopyBuffer(handleMA4, 0, 1, 2, bufferMA4);
   ArraySetAsSeries(bufferMA4, true);
   
   if(bufferMA4[0] > bufferMA4[1]) return UP;
   if(bufferMA4[0] < bufferMA4[1]) return DN;
   return NONE;
}


//V-образный паттерн младшего МА
ENUM_DIRECTION Signal__(){
   CopyBuffer(handleMA4, 0, 1, 3, bufferMA4);
   ArraySetAsSeries(bufferMA4, true);
   
   if(bufferMA4[0] > bufferMA4[1] && bufferMA4[2] > bufferMA4[1]) return UP;
   if(bufferMA4[0] < bufferMA4[1] && bufferMA4[2] < bufferMA4[1]) return DN;
   
   return NONE;
}

string DTS(const double d, const int digits = 5){
   return DoubleToString(d, digits);
}