//+------------------------------------------------------------------+
//|                                                          Sto.mq4 |
//|                                                      Ozkan CICEK |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ozkan CICEK"
#property link      "https://www.mql5.com"
#property version   "1.4.0.10"
#property strict

#define MAX_NUM_TRIALS 5
#define SIZE_SIGNALS 3

enum price_field{
   low_high = 0,
   close_close = 1
};
extern bool print_signals = false; // Print Stochastic Oscillator Signals 
extern double lot_to_open = 1.0;  // Lot to open
extern int slippage = 9; // Maximum price slippage for buy or sell orders
extern double stop_loss_pips = 4.0; // Stop loss pips
extern double take_profit_pips = 6.0; // Take profit pips
//extern bool one_order = FALSE; // Open only one order
extern int k_period = 5; // %K
extern int d_period = 3; // %D
extern int slowing = 3; // Slowing
extern ENUM_MA_METHOD averaging_method = MODE_SMA; // SO averaging method
extern price_field price_field_selected = low_high; // SO price field
extern int offset = 0; // SO offset
extern double max_spread = 2.0;
int num_orders_to_open = 1;
int num_open_orders = 0;
double main_signal = 0;
double mode_signal = 0;

int lfh = INVALID_HANDLE; ///< Log file handle
int alfh = INVALID_HANDLE; ///< Actions log file
//int previous_market_trend = 0;
bool debug = false;
bool orderOpened = false;

//+------------------------------------------------------------------+
//| Global functions                                                 |
//+------------------------------------------------------------------+

double getSpread()
{
   string sym = Symbol(); ///< Current chart's symbol
   double point = MarketInfo(sym, MODE_POINT) * 10.;
   double spread, bidPrice, askPrice;
   
   bidPrice = NormalizeDouble(MarketInfo(sym, MODE_BID), Digits);	
   askPrice = NormalizeDouble(MarketInfo(sym, MODE_ASK), Digits);
   spread = NormalizeDouble(MathAbs(bidPrice - askPrice), Digits)/point;
   
   return spread;   
}


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
      price = NormalizeDouble(MarketInfo(sym, MODE_BID), Digits);	
      if(sl_pips != 0){
         sl = price + sl_pips * point;
         sl = NormalizeDouble(sl, Digits);
      }
      if(tp_pips != 0){
         tp = price - tp_pips * point;
         tp = NormalizeDouble(tp, Digits);
      }
   }else if (op_type == OP_BUY){
      price = NormalizeDouble(MarketInfo(sym, MODE_ASK), Digits);
      if(sl_pips != 0){
         sl = price - sl_pips * point;
         sl = NormalizeDouble(sl, Digits);
      }
      if(tp_pips != 0){
         tp = price + tp_pips * point;
         tp = NormalizeDouble(tp, Digits);
      }
   }
   //FileWrite(alfh, "Price = ", price, ", Stop loss = ", sl, ", Take profit = ", tp);
   WriteActivity("Price = " + DoubleToString(price) + ", Stop loss = " + DoubleToString(sl) + ", Take profit = " + DoubleToString(tp));
   
   for (i_try = 0; i_try < MAX_NUM_TRIALS; i_try++){
      ticket = OrderSend(sym, op_type, lot, price, slippage, sl, tp);
      if (ticket != -1) break;
   }//end max trials
   if (i_try == MAX_NUM_TRIALS){
      int error = GetLastError();
      Comment(sym, " Paritesinde emir acilamadi. Hata kodu = ", error);
      WriteActivity("ERROR: " + sym + " paritesinde emir acilamadi. Hata kodu = " + IntegerToString(error)); 
   }else{
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
         int error = GetLastError();
         Comment("Emir secilemedi... Hata kodu : ", error);
         WriteActivity("ERROR: Emir secilemedi... Hata kodu = " + IntegerToString(error));
      }//end if order select
      write_log(ticket, OrderType(), "Open", OrderOpenPrice(), -9999, -9999, take_profit_pips, stop_loss_pips, lot_to_open);
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
            int error = GetLastError();
            Comment("Emir secilemedi... Hata kodu : ", error);
            WriteActivity("ERROR: Emir secilemedi... Hata kodu : " + IntegerToString(error));
            continue;
         }//end if order select
         if(OrderSymbol() != current_sym)   continue;         
         if(CloseOrder()){
            WriteActivity("ERROR: " + IntegerToString(OrderTicket()) + " No'lu emir kapatilamadi" + 
                           " .... Hata kodu = " + IntegerToString(GetLastError()));
         }else{
            write_log(OrderTicket(), OrderType(), "Close", NormalizeDouble(OrderOpenPrice(), Digits), 
                     NormalizeDouble(OrderClosePrice(), Digits), OrderProfit(), take_profit_pips, stop_loss_pips, lot_to_open);
         }//end if else CloseOrder  
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
   string com = "";
   int trend = 0; // do nothing
   int price_fields[2] = {0, 1};
   
   for(i_sig = 0; i_sig < SIZE_SIGNALS; i_sig++){
      i_history = offset + i_sig;
      main_signals[i_sig] = iStochastic(Symbol(), 0, k_period, d_period, slowing, averaging_method, price_fields[price_field_selected], MODE_MAIN, i_history); 
      mode_signals[i_sig] = iStochastic(Symbol(), 0, k_period, d_period, slowing, averaging_method, price_fields[price_field_selected], MODE_SIGNAL, i_history);
      smaller[i_sig] = main_signals[i_sig] < mode_signals[i_sig];
      sum += smaller[i_sig];
   }//end for i_sig
   
   main_signal = iStochastic(Symbol(), 0, k_period, d_period, slowing, averaging_method, price_fields[price_field_selected], MODE_MAIN, 0);
   mode_signal = iStochastic(Symbol(), 0, k_period, d_period, slowing, averaging_method, price_fields[price_field_selected], MODE_SIGNAL, 0);
      
   if (print_signals == true){
      com = "Main signal = " + DoubleToString(main_signal) + ", Mode signal = " + DoubleToString(mode_signal);
      Comment(com);
   }
   if(debug == true){
      com += "\n" + 
         "main[0] = " + DoubleToString(main_signals[0]) + ", main[-1] = " + DoubleToString(main_signals[1]) + ", main[-2] = " + DoubleToString(main_signals[2]) + "\n" + 
         "mode[0] = " + DoubleToString(mode_signals[0]) + ", mode[-1] = " + DoubleToString(mode_signals[1]) + ", mode[-2] = " + DoubleToString(mode_signals[2]) + "\n" +
         "smaller[0] = " + DoubleToString(smaller[0]) + ", smaller[-1] = " + DoubleToString(smaller[1]) + ", smaller[-2] = " + DoubleToString(smaller[2]);
         Comment(com);
   }
   
   // search for a change in direction
   if(sum != 0 || sum != SIZE_SIGNALS){
      // find out where market goes
      if(smaller[0] == 1 && smaller[SIZE_SIGNALS-1] == 0){
        trend = 1; // sell
      }else if (smaller[0] == 0 && smaller[SIZE_SIGNALS-1] == 1){
        trend = -1; // buy
      }
   }
   return trend; 
}

void write_log(int ticket, int op_type, string open_close, double open_price, double close_price, double profit, double tp_pips, double sl_pips, double lot)
{
   MqlDateTime str; 
   TimeToStruct(TimeCurrent(), str);
   string date = IntegerToString(str.year) + "/" + IntegerToString(str.mon) + "/" + IntegerToString(str.day);
   string time = IntegerToString(str.hour) + ":" + IntegerToString(str.min) + ":" + IntegerToString(str.sec);
   
   //"Date", "Time", "TicketNumber", "Position", "Open/Close", "Lot", "TakeProfitPips", "StopLossPips", "OpenPrice", "ClosePrice", "Profit"
   
   if(lfh != INVALID_HANDLE)  FileWrite(lfh, date, time, ticket, op_type==OP_BUY?"BUY":"SELL", open_close, lot, tp_pips, sl_pips, open_price, 
                                       close_price, profit);
}

void WriteActivity(string msg)
{
   if(alfh == INVALID_HANDLE) return;
   MqlDateTime str; 
   TimeToStruct(TimeCurrent(), str);
   string date = IntegerToString(str.year) + "/" + IntegerToString(str.mon) + "/" + IntegerToString(str.day);
   string time = IntegerToString(str.hour) + ":" + IntegerToString(str.min) + ":" + IntegerToString(str.sec);
   FileWrite(alfh, date, " ", time, " ", msg);
}

void TracePositions()
{
   int total_orders = 0;
   double profit = 0.0;
   total_orders = OrdersTotal();
   string current_sym = Symbol();
      
   if(total_orders != 0){
      for(int i = total_orders - 1; i >= 0; --i) {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            int error = GetLastError();
            Comment("Emir secilemedi... Hata kodu : ", error);
            WriteActivity("ERROR: Emir secilemedi... Hata kodu = " + IntegerToString(error));
            continue;
         }//end if order select
         if(OrderSymbol() != current_sym)   continue;
         int ticket = OrderTicket();
         int optype = OrderType();
         double open_price = OrderOpenPrice();
         double target_stop, target_profit;
         double bid, ask;
         if(optype == OP_BUY) {
            target_stop = NormalizeDouble((open_price - stop_loss_pips * 10. * Point), Digits);
            target_profit = NormalizeDouble((open_price + take_profit_pips * 10. * Point), Digits);
            bid = NormalizeDouble(Bid, Digits);
            WriteActivity("Target stop = " + DoubleToString(target_stop) + ", Target profit = " + DoubleToString(target_profit) + 
                          ", Bid = " + DoubleToString(bid));  
            //ask = NormalizeDouble(Ask, Digits);
            //if(bid > target_profit || ask < target_stop){
            if(bid >= target_profit || bid <= target_stop){
               if(CloseOrder()){
                  WriteActivity("ERROR: " + IntegerToString(ticket) + " No'lu emir kapatilamadi" +  
                                 " .... Hata kodu = " + IntegerToString(GetLastError()));
               }else{
                  write_log(ticket, OP_BUY, "Close", NormalizeDouble(open_price, Digits), 
                           NormalizeDouble(OrderClosePrice(), Digits), OrderProfit(), take_profit_pips, stop_loss_pips, lot_to_open);
                  orderOpened = false;
               }//end if else CloseOrder
            }//end if Bid Ask
         }else{
            target_stop = NormalizeDouble((open_price + stop_loss_pips * 10. * Point), Digits);
            target_profit = NormalizeDouble((open_price - take_profit_pips * 10. * Point), Digits);
            //bid = NormalizeDouble(Bid, Digits);
            ask = NormalizeDouble(Ask, Digits);
            WriteActivity("Target stop = " + DoubleToString(target_stop) + ", Target profit = " + DoubleToString(target_profit) + 
                          ", Ask = " + DoubleToString(ask)); 
            //if(ask < target_profit || bid > target_stop){
            if(ask <= target_profit || ask >= target_stop){
               if(CloseOrder()){
                  WriteActivity("ERROR: " + IntegerToString(ticket) + " No'lu emir kapatilamadi" + 
                                 " .... Hata kodu = " + IntegerToString(GetLastError()));
               }else{
                  write_log(ticket, OP_SELL, "Close", NormalizeDouble(open_price, Digits), 
                           NormalizeDouble(OrderClosePrice(), Digits), OrderProfit(), take_profit_pips, stop_loss_pips, lot_to_open);
                  orderOpened = false;
               }//end if else CloseOrder
            }//end if Bid Ask
         }//end if else optype  
      }//end for total_orders          
   }//end if total_orders != 0
}

/*! Close the order selected with OrderSelect function */
int CloseOrder()
{
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
      //Comment(OrderTicket(), " No'lu emir kapatilamadi close price = ", close_price, " .... Hata kodu : ", GetLastError());
      return -1;
   }//end if max trial     
   return 0;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  string fn = "S_log_" + Symbol() + ".csv";
  lfh = FileOpen(fn, FILE_WRITE | FILE_CSV);
  if(lfh != INVALID_HANDLE)   FileWrite(lfh, "Date", "Time", "TicketNumber", "Position", "Open/Close", "Lot", "TakeProfitPips", "StopLossPips", "OpenPrice", "ClosePrice", "Profit");  

  fn = "S_log_activity_" + Symbol() + ".txt";
  alfh = FileOpen(fn, FILE_WRITE | FILE_TXT);
  if(alfh != INVALID_HANDLE)  FileWrite(alfh, "lot to open = ", DoubleToString(lot_to_open), ", stop loss pips = ", DoubleToString(stop_loss_pips), "\n",
                                              "take profit pips = ", DoubleToString(take_profit_pips), ", %K = ", IntegerToString(k_period), "\n",
                                              "%D = ", IntegerToString(d_period), ", slowing = ", IntegerToString(slowing), 
                                              ", Price Field = ", price_field_selected==low_high?"Low/High":"Close/Close");
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
   double spread; 
   
   TracePositions();
   if (orderOpened) return; // open only one order
   
   market_trend = checkStochasticSignal();
   
   spread = getSpread();   
   if (spread > max_spread) return;
   
   //if((market_trend != previous_market_trend) && (market_trend == 1)){
   if (market_trend == 1) {
      WriteActivity("Market has gone in sell direction");
      /*
      if(one_order == TRUE){
         if(closeAllOrders()){
            Comment("Cannot close all orders");
            WriteActivity("ERROR: Cannot close all orders");
         }
      }//end if one_order              
      */
      if(openOrder(OP_SELL, lot_to_open, 0.0, 0.0)){
         //Comment(Symbol(), " Paritesinde satis emiri acilamadi.");
      }else{
         //previous_market_trend = market_trend;
         orderOpened = true;  
      }
   //}else if((market_trend != previous_market_trend) && (market_trend == -1)){
   }else if (market_trend == -1) {
      WriteActivity("Market has gone in buy direction");
      /*
      if(one_order == TRUE){
         if(closeAllOrders()){
            Comment("Cannot close all orders");
            WriteActivity("ERROR: Cannot close all orders");
         }
      }//end if one_order
      */
      if(openOrder(OP_BUY, lot_to_open, 0.0, 0.0)){
         //Comment(Symbol(), " Paritesinde alis emiri acilamadi.");
      }else{
         //previous_market_trend = market_trend;
         orderOpened = true;
      }
   }//enf if market_trend  
   
}
//+------------------------------------------------------------------+
