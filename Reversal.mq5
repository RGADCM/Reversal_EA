//+------------------------------------------------------------------+
//|                                                     Reversal.mq5 |
//|                                             Copyright 2019, ADCM |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright     "ADCM"
#property version       "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

int               shift = 1;                                       //The shift used by this indicator
int               handle_icustom;
string            current_symbol;                                  //переменная для хранения символа
ENUM_TIMEFRAMES   current_timeframe;                               //переменная для хранения таймфрейма
CTrade            m_Trade;                                         //структура для выполнения торговых операций
CPositionInfo     m_Position;                                      //структура для получения информации о позициях
double            tp1;
bool              halfclosed;

//--- input parameters
input    string   stub1 = "========Indicator Settings========";               //========Indicator Settings========
input    string   pathToIndicator = "Market\\PipFinite_Reversal_PRO_MT5";     // Path to indicator
input    int      signalPeriod = 2;                                           // Signal Period
input    int      zonePeriod = 5;                                             // Zone Period
input    double   zoneDeviation = 1.45;                                       // Zone Deviation
input    int      stoplossMode = 3;                                           // Stop Loss Selection
input    int      stoplossOffset = 20;                                        // Stop Loss Offset(Points)
input    double   takeProfitFactor = 2.5;                                     // Take Profit Factor
input    int      lookback = 3000;                                            // Maximum History Bars
input    string   stub2 = "========Additional Settings========";              //========Additional Settings========
input    int      succsessRateForOpenTrade = 75;                              // Succsess Rate For Open Trade
input    int      expertMagicNumber = 1;                                      // Expert Magic Number
input    double   orderVolume = 0.1;                                               // Order volume
input    string   orderComment = "EURUSD_M15";                                     // Comment
input    bool     useTp2 = true;                                              // Use TP2
input    bool     closeHalfPositionOnTp1 = true;                              // Close half position on TP1 (if TP2 use)
input    int      pointsStopLossNearTakeProfit1 =  0;                         // Points to set stopLoss under first takeProfit

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   current_symbol=Symbol();                                             //сохраним текущий символ графика для дальнейшей работы советника именно на этом символе
   current_timeframe=PERIOD_CURRENT;                                    //сохраним текущий период графика для дальнейшей работы советника именно на этом период
   halfclosed = false;

//Load EX5
   handle_icustom = iCustom(current_symbol, current_timeframe, pathToIndicator, " ",
                            signalPeriod, zonePeriod, zoneDeviation, stoplossMode, stoplossOffset, takeProfitFactor, lookback);

//--- Нужно проверить, не были ли возвращены значения Invalid Handle
   if(handle_icustom==INVALID_HANDLE)                                  //проверяем наличие хендла индикатора
     {
      Print("Не удалось получить хендл индикатора");               //если хендл не получен, то выводим сообщение в лог об ошибке
      return(-1);                                                  //завершаем работу с ошибкой
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handle_icustom);                                   //удаляет хэндл индикатора и освобождает память занимаемую им
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//Close half position on TP1 hit
   if(closeHalfPositionOnTp1 && m_Position.SelectByMagic(current_symbol, expertMagicNumber))
     {
      double difference;

      if(m_Position.PositionType()==POSITION_TYPE_SELL)
        {
         double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         difference = current_ask - tp1;
        }
      else
         if(m_Position.PositionType()==POSITION_TYPE_BUY)
           {
            double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            difference = tp1 - current_bid;
           }
         else
           {
            Alert("Unexpected execption. POSITION_TYPE not SELL or BUY");
            return;
           }

      double rezult=difference*MathPow(10,Digits());

      if(!halfclosed && rezult <= 5)
        {
         if(m_Trade.PositionClosePartial(m_Position.Ticket(), orderVolume/2))
           {
            halfclosed = true;
           }
         else
           {
            Alert("Ошибка закрытия половины сделки, номер ошибки = ",GetLastError());
           }
        }
     }

// Check is new bar
   bool isNewBar = checkNewBar();
   if(!isNewBar)
     {
      return;
     }

   double succsessRateFromIndicator = GetIndicatorValue(31); //Success Rate% (31)

// Use TP1 in order or use TP2
   double takeProfitForOrder;
   if(useTp2)
     {
      takeProfitForOrder = GetIndicatorValue(10); //TP2 Price (10)
     }
   else
     {
      takeProfitForOrder = GetIndicatorValue(9); //TP1 Price (9)
     }
// Open deal
   if((GetIndicatorValue(7) > 0) && (succsessRateFromIndicator >= succsessRateForOpenTrade))  //Buy Signal (7)
     {
      if(m_Position.SelectByMagic(current_symbol, expertMagicNumber))
        {
         m_Trade.PositionClose(m_Position.Ticket());
        }
      m_Trade.SetExpertMagicNumber(expertMagicNumber);
      tp1 = GetIndicatorValue(9);
      m_Trade.Buy(orderVolume, current_symbol, NULL, GetIndicatorValue(11) /*SL Price (11)*/, takeProfitForOrder, orderComment);
      halfclosed = false;
     }

   if((GetIndicatorValue(8) > 0) && (succsessRateFromIndicator >= succsessRateForOpenTrade)) //Sell Signal (8)
     {
      if(m_Position.SelectByMagic(current_symbol, expertMagicNumber))
        {
         m_Trade.PositionClose(m_Position.Ticket());
        }
      m_Trade.SetExpertMagicNumber(expertMagicNumber);
      tp1 = GetIndicatorValue(9);
      m_Trade.Sell(orderVolume, current_symbol, NULL, GetIndicatorValue(11) /*SL Price (11)*/, takeProfitForOrder, orderComment);
      halfclosed = false;
     }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTrade()
  {


  }

//+------------------------------------------------------------------+
//| Get indicator values based on buffer number.                     |
//+------------------------------------------------------------------+
double GetIndicatorValue(int buffer)
  {
   if(shift < 0)
     {
      return(NULL);
     }
   double Arr[1];
   if(CopyBuffer(handle_icustom,buffer,shift,1,Arr)>0)
     {
      return(Arr[0]);
     }
   return(NULL);
  }
//+------------------------------------------------------------------+
bool checkNewBar()
  {

// Для сохранения значения времени бара мы используем static-переменную oldTimeBar.
// При каждом выполнении функции OnTick мы будем сравнивать время текущего бара с сохраненным временем.
// Если они не равны, это означает, что начал строится новый бар.
   static datetime oldTime;
   datetime newTime[1];

// копируем время текущего бара в элемент New_Time[0]
   int copied=CopyTime(_Symbol,_Period,0,1,newTime);
   if(copied>0) // ok, успешно скопировано
     {
      if(oldTime!=newTime[0]) //if oldTime not equals
        {
         oldTime=newTime[0];   // save bar time
         return true;
        }
      else
        {
         return false;
        }
     }
   else
     {
      Alert("Ошибка копирования времени, номер ошибки = ",GetLastError());
      ResetLastError();
      return false;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
