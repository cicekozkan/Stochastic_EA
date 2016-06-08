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

extern double lot_to_open = 1.0;  ///< Lot to open
int slippage = 10; ///< Maximum price slippage for buy or sell orders
extern double stop_loss_pips = 4.0; ///< Stop loss pips
extern double take_profit_pips = 6.0; ///< Take profit pips
int num_orders_to_open = 1;
int num_open_orders = 0;
double main_signal = 0;
double mode_signal = 0;
int k_period = 5;
int d_period = 3;
int slowing = 3;
int lfh = INVALID_HANDLE; ///< Log file handle

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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  if(openOrder(OP_BUY, lot_to_open, stop_loss_pips, take_profit_pips))  Comment(Symbol(), " Paritesinde emir acilamadi.");
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{

   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  main_signal = iStochastic(Symbol(), 0, k_period, d_period, slowing, MODE_SMA, 1, MODE_MAIN, 0);
  mode_signal = iStochastic(Symbol(), 0, k_period, d_period, slowing, MODE_SMA, 1, MODE_SIGNAL, 0);
  Comment("Main signal = ", main_signal, ", Mode signal = ", mode_signal);
  
  
  
  
  
}
//+------------------------------------------------------------------+
