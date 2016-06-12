//+------------------------------------------------------------------+
//|                                                          Sto.mq4 |
//|                                                      Ozkan CICEK |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ozkan CICEK"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define MAX_NUM_TRIALS 5
#define SIZE_SIGNALS 3

extern double lot_to_open = 1.0;  // Lot to open
int slippage = 10; ///< Maximum price slippage for buy or sell orders
extern double stop_loss_pips = 4.0; // Stop loss pips
extern double take_profit_pips = 6.0; // Take profit pips
extern int k_period = 5; // %K
extern int d_period = 3; // %D
extern int slowing = 3; // Slowing
extern bool one_order = FALSE; // Open only one order
extern ENUM_MA_METHOD averaging_method = MODE_SMA; // SO averaging method
int num_orders_to_open = 1;
int num_open_orders = 0;
double main_signal = 0;
double mode_signal = 0;

int lfh = INVALID_HANDLE; ///< Log file handle
int alfh = INVALID_HANDLE; ///< Actions log file
int previous_market_trend = 0;

//+------------------------------------------------------------------+
//| Global functions                                                 |
//+------------------------------------------------------------------+
/*!
Open order in current chart's symbol
*/ 
int openOrder(int op_type, double lot, double sl_pips, double tp_pips)
{
   string sym = Symbol(); ///< Current chart's symbol
   int ticket = -1;
   double price = 0.0;
   double point = MarketInfo(sym, MODE_POINT) * 10.;
   double sl = 0.0, tp = 0.0;
   int i_try = 0;
   
   if(op_type == OP_SELL){
      price = MarketInfo(sym, MODE_BID);	
      if(sl_pips != 0.0)   sl = price + sl_pips * point;
      if(tp_pips != 0.0)   tp = price - tp_pips * point;
   }else if (op_type == OP_BUY){
      price = MarketInfo(sym, MODE_ASK);
      if(sl_pips != 0.0)   sl = price - sl_pips * point;
      if(tp_pips != 0.0)   tp = price + tp_pips * point;
   }
   
   for (i_try = 0; i_try < MAX_NUM_TRIALS; i_try++){
      ticket = OrderSend(sym, op_type, lot, price, slippage, sl, tp);
      if (ticket != -1) break;
   }//end max trials
   if (i_try == MAX_NUM_TRIALS){
      Comment(sym, " Paritesinde emir acilamadi. Hata kodu = ", GetLastError()); 
   }
   return !(i_try < MAX_NUM_TRIALS); 
}

int closeAllOrders()
{  
   int total_orders = 0;
   total_orders = OrdersTotal();
   string current_sym = Symbol();
   if(total_orders != 0){
      for(int i = total_orders - 1; i >= 0; --i) {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            Comment("Emir secilemedi... Hata kodu : ", GetLastError());
            continue;
         }//end if order select
         if(OrderSymbol() != current_sym)   continue;
         int optype = OrderType();
         int k = 0;
         double close_price = 0.0;
         for(k = 0; k < MAX_NUM_TRIALS; ++k) {
            if(optype == OP_BUY)
      	      close_price = MarketInfo(OrderSymbol(), MODE_BID);
            else
      	      close_price = MarketInfo(OrderSymbol(), MODE_ASK);
            if(OrderClose(OrderTicket(), OrderLots(), close_price, 10))
      	      break;
            RefreshRates();
         }// end for trial
         if(k == MAX_NUM_TRIALS) {
            Comment(OrderTicket(), " No'lu emir kapatilamadi close price", close_price, " .... Hata kodu : ", GetLastError());
            return -1;
         }//end if max trial     
      }// end order total for
   }//end if total_orders != 0
   return 0;
}

/*!
   \return 1: sell, -1: buy, 0: do nothing
*/
int checkStochasticSignal()
{
   double main_signals[SIZE_SIGNALS] = {0.0}, mode_signals[SIZE_SIGNALS] = {0.0};
   int i_sig = 0, i_history = 0;
   int smaller[SIZE_SIGNALS] = {0};
   int sum = 0;
   string com;
   int trend = 0; // do nothing
   MqlDateTime str; 
   TimeToStruct(TimeCurrent(), str);
   string date = IntegerToString(str.year) + "/" + IntegerToString(str.mon) + "/" + IntegerToString(str.day);
   string time = IntegerToString(str.hour) + ":" + IntegerToString(str.min) + ":" + IntegerToString(str.sec);
   
   for(i_sig = 0; i_sig < SIZE_SIGNALS; i_sig++){
      i_history = 1 + i_sig;
      main_signals[i_sig] = iStochastic(Symbol(), 0, k_period, d_period, slowing, averaging_method, 1, MODE_MAIN, i_history); 
      mode_signals[i_sig] = iStochastic(Symbol(), 0, k_period, d_period, slowing, averaging_method, 1, MODE_SIGNAL, i_history);
      smaller[i_sig] = main_signals[i_sig] < mode_signals[i_sig];
      sum += smaller[i_sig];
   }//end for i_sig
   
   main_signal = iStochastic(Symbol(), 0, k_period, d_period, slowing, averaging_method, 1, MODE_MAIN, 0);
   mode_signal = iStochastic(Symbol(), 0, k_period, d_period, slowing, averaging_method, 1, MODE_SIGNAL, 0);
   //Comment("Main signal = ", main_signal, ", Mode signal = ", mode_signal);
      
   com = "Main signal = " + DoubleToString(main_signal) + ", Mode signal = " + DoubleToString(mode_signal) + "\n" + 
         "main[0] = " + DoubleToString(main_signals[0]) + ", main[-1] = " + DoubleToString(main_signals[1]) + ", main[-2] = " + DoubleToString(main_signals[2]) + "\n" + 
         "mode[0] = " + DoubleToString(mode_signals[0]) + ", mode[-1] = " + DoubleToString(mode_signals[1]) + ", mode[-2] = " + DoubleToString(mode_signals[2]) + "\n" +
         "smaller[0] = " + DoubleToString(smaller[0]) + ", smaller[-1] = " + DoubleToString(smaller[1]) + ", smaller[-2] = " + DoubleToString(smaller[2]);
   //Comment(com);
   
   // search for a change in direction
   if(sum != 0 || sum != SIZE_SIGNALS){
      // find out where market goes
      if(smaller[0] == 1 && smaller[SIZE_SIGNALS-1] == 0){
        //return 1; // sell
        FileWrite(alfh, "Market has gone in sell direction on ", date," ", time);
        trend = 1; // sell
      }else if (smaller[0] == 0 && smaller[SIZE_SIGNALS-1] == 1){
        //return -1;  //buy
        FileWrite(alfh, "Market has gone in buy direction on ", date," ", time);
        trend = -1; // but
      }
   }
   return trend; 
}

void write_log(int op_type, string open_close)
{
   MqlDateTime str; 
   TimeToStruct(TimeCurrent(), str);
   string date = IntegerToString(str.year) + "/" + IntegerToString(str.mon) + "/" + IntegerToString(str.day);
   string time = IntegerToString(str.hour) + ":" + IntegerToString(str.min) + ":" + IntegerToString(str.sec);
   
   if(lfh != INVALID_HANDLE)  FileWrite(lfh, date, time, Symbol(), op_type==OP_BUY?"BUY":"SELL", open_close);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  //if(openOrder(OP_BUY, lot_to_open, stop_loss_pips, take_profit_pips))  Comment(Symbol(), " Paritesinde emir acilamadi.");
  lfh = FileOpen("S_log.csv", FILE_WRITE | FILE_CSV);
  if(lfh != INVALID_HANDLE)   FileWrite(lfh, "Date", "Time", "Parity", "Position", "Open/Close");  
  alfh = FileOpen("S_log_activity.txt", FILE_WRITE | FILE_TXT);
  if(alfh != INVALID_HANDLE)  FileWrite(alfh, "lot to open = ", DoubleToString(lot_to_open), ", stop loss pips = ", DoubleToString(stop_loss_pips), "\n",
                                              "take profit pips = ", DoubleToString(take_profit_pips), ", %K = ", IntegerToString(k_period), "\n",
                                              "%D = ", IntegerToString(d_period), ", slowing = ", IntegerToString(slowing));
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(lfh != INVALID_HANDLE)  FileClose(lfh);
   if(alfh != INVALID_HANDLE)  FileClose(alfh);
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   int market_trend = 0;
   //main_signal = iStochastic(Symbol(), 0, k_period, d_period, slowing, MODE_SMA, 1, MODE_MAIN, 0);
   //mode_signal = iStochastic(Symbol(), 0, k_period, d_period, slowing, MODE_SMA, 1, MODE_SIGNAL, 0);
   //Comment("Main signal = ", main_signal, ", Mode signal = ", mode_signal); 
   
   market_trend = checkStochasticSignal();
   
   if((market_trend != previous_market_trend) && (market_trend == 1)){
      if(one_order == TRUE){
         if(closeAllOrders()) Comment("Cannot close all orders");
         else write_log(OP_BUY, "Close");
      }//end if one_order
      if(openOrder(OP_SELL, lot_to_open, stop_loss_pips, take_profit_pips)){
         //Comment(Symbol(), " Paritesinde satis emiri acilamadi.");
      }else{
         write_log(OP_SELL, "Open"); 
         previous_market_trend = market_trend;  
      }
   }else if((market_trend != previous_market_trend) && (market_trend == -1)){
      if(one_order == TRUE){
         if(closeAllOrders()) Comment("Cannot close all orders");
         else write_log(OP_SELL, "Close");
      }//end if one_order
      if(openOrder(OP_BUY, lot_to_open, stop_loss_pips, take_profit_pips)){
         //Comment(Symbol(), " Paritesinde alis emiri acilamadi.");
      }else{
         write_log(OP_BUY, "Open");
         previous_market_trend = market_trend;
      }
   }//enf if market_trend  
   
}
//+------------------------------------------------------------------+
