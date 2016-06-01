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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  string sym = Symbol(); ///< Current chart's symbol
  int op_type = OP_BUY; ///< Operation
  int k = 0;
  int ticket = -1;
  double price = 0.0;
  double point = MarketInfo(sym, MODE_POINT) * 10.;
  double tp = 0.0, sl = 0.0;
  
  if(num_open_orders < num_orders_to_open){
    if(op_type == OP_SELL){
      price = MarketInfo(sym, MODE_BID);	
      sl = price + stop_loss_pips * point;
      tp = price - take_profit_pips * point;
    }else if (op_type == OP_BUY){
      price = MarketInfo(sym, MODE_ASK);
      sl = price - stop_loss_pips * point;
      tp = price + take_profit_pips * point;
    }

    for (k = 0; k < MAX_NUM_TRIALS; k++){
      ticket = OrderSend(sym, op_type, lot_to_open, price, slippage, sl, tp);
      if (ticket != -1) break;
    }//end max trials
    if (k == MAX_NUM_TRIALS){
      Comment(sym, " Paritesinde emir acilamadi. Hata kodu = ", GetLastError());
    }else{
      ++num_open_orders;
    }
  }//end if num_open_orders    
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
