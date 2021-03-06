//+------------------------------------------------------------------+
//|                                                     Impulse_0.01 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//Версия 0.02
//Добавлен "Чистый импульс" (PureImpulse), который рассчитывается НА КАЖДОМ ТИКЕ
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <OrderPosition.mqh>

enum ENUM_DIRECTION{
   null,    //не использовать
   indir,   //по направлению
   agdir    //против направления
};

input int MAGIC = 910101;        //Магик
input string OPEN_SESSION = "10:00";
input string CLOSE_SESSION = "18:00";
input string comment01 = "";     //ПАРАМЕТРЫ ВХОДА В СДЕЛКУ
input int LENGTH = 40;           //Длина свечи (пункты)
input int IMPULSE_TIME = 100;    //Время формирования импульса (сек)
input int IMPULSE = 10;          //Импульс

input string comment02 = "";     //ПАРАМЕТРЫ ОРДЕРОВ
input int OFFSET_BUY_STOP = 50;  //Отступ бай стоп от Ask
input int OFFSET_SELL_STOP = 50; //Отступ селл стоп от Bid
input int ORDER_TRAL_STEP = 10;  //Order tral step
input int TP_BUY_STOP = 40;      //TP бай стоп
input int SL_BUY_STOP = 20;      //SL бай стоп
input int TP_SELL_STOP = 40;     //TP селл стоп
input int SL_SELL_STOP = 20;     //SL селл стоп
input double LOT = .01;

input string comment03 = "";     //СОПРОВОЖДЕНИЕ СДЕЛОК
input int BREAKEVEN = 5;         //Безубыток
input int TRAL_STEP = 10;        //Tral step (шаг коррекции модификации стоплосса в пунктах)
input int TRAL_STOP = 10;        //Tral stop (дистанция стоплосса от цены в пунктах)
input bool IS_AUTO_LOT = false;  //Автолот от риска (false/true)
input double RISK = 5;           //Риск для автолота (в %)

input string comment04 = "";     //"ПАРАМЕТРЫ ЭКВИТИ-КОНТРОЛЯ"
input bool AUTO_CLOSE = true;   //Автозакрытие по профиту/просадки (false/true)
input double PROFIT = 5;        //Профит %
input double LOSS = -2;         //Просадка %

input string comment05 = "";     //"ПАРАМЕТРЫ МА"
input ENUM_DIRECTION dir = null; //Использование МА (по направлению, против направления, не использовать МА (выкл.)
input int MA_PERIOD = 16;        //МА период
input int MA_SHIFT = 0;          //МА сдвиг

int maHandle;
double maBuffer[];

//Указываем, что экземпляр будет сверять свои значения с магиком
OrderPosition p;
CSymbolInfo smb;

typedef int(*ptr)();
ptr Signal;
int mtp = 1;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
//--- create timer
   EventSetTimer(1);   
   Signal = PureImpulse;
   if(Digits() == 5 || Digits() == 3)mtp = 10;
   maHandle = iMA(Symbol(), PERIOD_CURRENT, MA_PERIOD, MA_SHIFT, MODE_EMA, PRICE_CLOSE);
   //С этим магиком будут устанавливаться все сделки
   p.Init();
   //ИЩЕМ ОРДЕРА, КОТОРЫЕ ВЫСТАВИЛИ РАНЕЕ
//---
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
//---
   p.UpdateOrders();
   if(!p.IsPending()){
      if(IsTradingTime()){
         int s = Signal();
         switch(s){
            case 0: break; //buy
            case 1: break; //sell
            case 2: break; //buyLimit
            case 3: break; //sellLimit
            case 4: p.BuyStop (Lot(RISK, SL_BUY_STOP),  OFFSET_BUY_STOP,  SL_BUY_STOP,  TP_BUY_STOP); break;
            case 5: p.SellStop(Lot(RISK, SL_SELL_STOP), OFFSET_SELL_STOP, SL_SELL_STOP, TP_SELL_STOP);break;
         }
      }
   }
   //Если какие-то ордера есть, то тралим их и их стопы и смотрим, чтобы не вывалились за эквити.
   
   for(int i = 0; i < p.GetSize(); i++){
      switch(p.GetType(i)){
         //TRAL_STOPS
         case 0:;
         case 1: p.TralStop(i, BREAKEVEN, TRAL_STOP, TRAL_STEP);break;
         //TRAL_ORDERS 
         case 4: p.TralBuyStop(i, OFFSET_BUY_STOP, ORDER_TRAL_STEP);break;
         case 5: p.TralSellStop(i, OFFSET_SELL_STOP, ORDER_TRAL_STEP);break;
      }           
   }
   //EQUITY_CONTROL
   if(AUTO_CLOSE){
      double drawDown = NormalizeDouble(p.GetProfit() / (AccountInfoDouble(ACCOUNT_BALANCE) / 100), 2);      
      if(drawDown < LOSS || PROFIT < drawDown){
         for(int i = 0; i < p.GetSize(); i++){
            p.Close((int)p.GetTicket(i));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer(){
//---
   
}
//+------------------------------------------------------------------+

void OnTrade(){
   //ПРОВЕРЯЕМ ВЫСТАВЛЕННЫЕ ПОЗИЦИИ. ДЕЙСТВУЕМ, КОГДА ОРДЕРОВ НЕТ

}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
//--- destroy timer
   EventKillTimer();   
   Comment("");
}

double Lot(const double r, const int pt){
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lot = LOT;
   
   if(IS_AUTO_LOT && pt > 0 && r > 0){
      lot = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE)/100*r/(pt*(SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE))), 2);
   }
   
   if(lot > maxLot)lot = maxLot;
   if(lot < minLot)lot = minLot;
   return lot;
}


bool IsTradingTime(){
   static datetime oSession = 0; 
   static datetime cSession = 0; 
   oSession = StringToTime(OPEN_SESSION);
   cSession = StringToTime(CLOSE_SESSION);
   
   //ЕСЛИ oSession больше, чем cSession, то к oSession прибавляем один день
   if(oSession >= cSession)cSession += 86400;
   if(oSession <= TimeCurrent() && TimeCurrent() < cSession)
      return true;
   return false;
}

//ЗДЕСЬ ВАЛЯЮТСЯ ВСЕ СИГНАЛЬНЫЕ ФУНКЦИИ, КОТОРЫЕ ВЫЗЫВАЮТСЯ ЧЕРЕЗ УКАЗАТЕЛЬ Signal
int Impulse(){
   static datetime startTime = 0;
   static double startPrice = 0.0;
   datetime currentTime;
   datetime deltaTime;
   double deltaPrice;
   double length = NormalizeDouble(LENGTH * Point() * mtp, Digits());
   double impulse = NormalizeDouble(IMPULSE * Point() * mtp, Digits());
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   CopyRates(Symbol(), PERIOD_CURRENT, 0, 1, rates);
   //Если свеча достигла размера
   if(rates[0].high - bid > length ||
      bid - rates[0].low > length){
      //то начинаем искать импульс, задав стартовое время и стартовую цену
      if(startTime == 0){
         startTime = TimeCurrent();
         startPrice = bid;
      }
      currentTime = TimeCurrent();
      deltaTime = currentTime - startTime;
      deltaPrice = bid - startPrice;
      //Если найден импульс и время не вышло, то возвращаем номер сигнала
      if(deltaTime < IMPULSE_TIME && MathAbs(deltaPrice) >= impulse){
         CopyBuffer(maHandle, 0, 0, 2, maBuffer);
         if(deltaPrice < 0){
            if(dir == null || 
              (dir == indir && ask > maBuffer[0] && ask > maBuffer[1]) ||
              (dir == agdir && ask < maBuffer[0] && ask < maBuffer[1]))
               return 4;
         }
         else{
            if(dir == null || 
              (dir == indir && bid < maBuffer[0] && bid < maBuffer[1]) ||
              (dir == agdir && bid > maBuffer[0] && bid > maBuffer[1]))
            return 5;
         }
      }
      
   }
   else startTime = 0;
   
   return -1;
}

//Сигнал "Чистого импульса"
//Содержит индекс, который инкрементируется каждый тик
//Пара обнуляется, когда таймер достигает заданного времени (в секундах)
/*int PureImpulse(){
   static int timer = 0;
   static int index = 0;   //индекс пары (стартовая цена/стартовое время)
   
   index++;
   struct Pair{
      double price;
      datetime time;
   };
   
   static Pair pair[];
   int size = ArraySize(pair);
   if(size < index + 1)ArrayResize(pair, index+1);
   
   //сохраняем текущее время и цену в пару
   pair[index].price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   pair[index].time = TimeCurrent();
      
   //Пробегаемся на каждом тике по всему массиву и ищем импульс
   for(int i = 0; i <= size; i++){
      if(pair[i].time > IMPULSE_TIME){
         pair[i].price = 0.0;
         pair[i].time = 0;
      }
      
      //Print("["+i+"] "+pair[i].price+"   "+pair[i].time+"   Size: "+ArraySize(pair));
   }
   //Индекс увеличивается на каждом тике
   index++;
   return -1;
}*/

int PureImpulse(){
   struct Pair{
      double price;
      datetime time;
   };
   static Pair pair;
   if(pair.price == 0.0){
      pair.price = Bid;
      pair.time  = TimeCurrent();
   }
   
   if(pair.time > IMPULSE_TIME)pair.price = 0.0;
   if(pair.price != 0.0){
      if(pair.price - Bid > IMPULSE)return SELL;
      if(Bid - pair.price > IMPULSE)return BUY;
   }
   return -1;
}