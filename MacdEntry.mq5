#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//Input Variables
input group "=== Indicators ==="
input int ssma1 = 21;
input int ssma2 = 50;
input int ssma3 = 200;

input group "=== Stop loss and take profit (in points)"
input int SL = 100;     //Stop loss
input int TP = 200;     //Take profit

input group "=== Risk management ==="
input double percentRisk = 1.0;    //Risk in percentage

//Global Variables
int ssma1Handle;
int ssma2Handle;
int ssma3Handle;

int ssmaH1Handle;
int ssmaH2Handle;
int ssmaH3Handle;

int macdHandle;

double ssma1Buffer[];
double ssma2Buffer[];
double ssma3Buffer[];

double ssmaH1Buffer[];
double ssmaH2Buffer[];
double ssmaH3Buffer[];

double macdLineBuffer[];
double signalLineBuffer[];

datetime openTimeBuy = 0;
datetime openTimeSell = 0;
CTrade trade;

//Expert initialization function
int OnInit() 
{
   if(percentRisk <= 0)
   {
      Alert("Invalid lot size");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(ssma1 <= 0)
   {
      Alert("Invalid ssma1 period");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(ssma2 <= 0)
   {
      Alert("Invalid ssma2 period");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(ssma3 <= 0)
   {
      Alert("Invalid ssma3 period");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(SL <= 0)
   {
      Alert("Invalid SL");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(TP <= 0)
   {
      Alert("Invalid TP");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   ssma1Handle = iMA(_Symbol, PERIOD_CURRENT, ssma1, 0, MODE_SMMA, PRICE_CLOSE);
   if(ssma1Handle == INVALID_HANDLE)
   {
      Alert("SSMA1 handle failure");
      return INIT_FAILED;
   }
   
   ssma2Handle = iMA(_Symbol, PERIOD_CURRENT, ssma2, 0, MODE_SMMA, PRICE_CLOSE);
   if(ssma2Handle == INVALID_HANDLE)
   {
      Alert("SSMA2 handle failure");
      return INIT_FAILED;
   }
   
   ssma3Handle = iMA(_Symbol, PERIOD_CURRENT, ssma3, 0, MODE_SMMA, PRICE_CLOSE);
   if(ssma3Handle == INVALID_HANDLE)
   {
      Alert("SSMA3 handle failure");
      return INIT_FAILED;
   }
   
   ssmaH1Handle = iMA(_Symbol, PERIOD_H1, ssma1, 0, MODE_SMMA, PRICE_CLOSE);
   if(ssmaH1Handle == INVALID_HANDLE)
   {
      Alert("SSMAH1 handle failure");
      return INIT_FAILED;
   }
   
   ssmaH2Handle = iMA(_Symbol, PERIOD_H1, ssma2, 0, MODE_SMMA, PRICE_CLOSE);
   if(ssmaH2Handle == INVALID_HANDLE)
   {
      Alert("SSMAH2 handle failure");
      return INIT_FAILED;
   }
   
   ssmaH3Handle = iMA(_Symbol, PERIOD_H1, ssma3, 0, MODE_SMMA, PRICE_CLOSE);
   if(ssmaH3Handle == INVALID_HANDLE)
   {
      Alert("SSMAH3 handle failure");
      return INIT_FAILED;
   }
   
   macdHandle = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
   if(macdHandle == INVALID_HANDLE)
   {
      Alert("Macd handle failure");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(ssma1Buffer, true);
   ArraySetAsSeries(ssma2Buffer, true);
   ArraySetAsSeries(ssma3Buffer, true);
   ArraySetAsSeries(ssmaH1Buffer, true);
   ArraySetAsSeries(ssmaH2Buffer, true);
   ArraySetAsSeries(ssmaH3Buffer, true);
   ArraySetAsSeries(macdLineBuffer, true);
   ArraySetAsSeries(signalLineBuffer, true);
   
   return(INIT_SUCCEEDED);
}

//Expert deinitialization function
void OnDeinit(const int reason)
{
   if(ssma1Handle != INVALID_HANDLE)
   {
      IndicatorRelease(ssma1Handle);
   }
   
   if(ssma2Handle != INVALID_HANDLE)
   {
      IndicatorRelease(ssma2Handle);
   }
   
   if(ssma3Handle != INVALID_HANDLE)
   {
      IndicatorRelease(ssma3Handle);
   }
   
   if(ssmaH1Handle != INVALID_HANDLE)
   {
      IndicatorRelease(ssmaH1Handle);
   }
   
   if(ssmaH2Handle != INVALID_HANDLE)
   {
      IndicatorRelease(ssmaH2Handle);
   }
   
   if(ssmaH3Handle != INVALID_HANDLE)
   {
      IndicatorRelease(ssmaH3Handle);
   }
   
   if(macdHandle != INVALID_HANDLE)
   {
      IndicatorRelease(macdHandle);
   }
}

//Calculate Lots
bool CalculateLots(double SlForCalc, double &lotCalc)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * percentRisk * 0.01;
   double moneyVolumeStep = (SlForCalc / tickSize) * tickValue * volumeStep;
   
   lotCalc = (riskMoney / moneyVolumeStep) * volumeStep;
   
   if(!CheckLots(lotCalc))
   {
      return false;
   }
      
   return true;
}

//Check Lots
bool CheckLots(double &lots)
{
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lots < min)
   {
      Print("Lot: ", lots, " lower than minimum allowed: ", min);
      return false;
   }
   else if(lots > max)
   {
      Print("Lot: ", lots, " higher than maximum allowed: ", max);
      return false;
   }
   
   lots = (int)MathFloor(lots/step) * step;
   return true;
}

//Expert tick function
void OnTick(){
   int values = CopyBuffer(ssma1Handle, 0, 0, 2, ssma1Buffer);
   if(values != 2){
      Print("Not enough data for ssma1");
      return;
   }
   
   values = CopyBuffer(ssma2Handle, 0, 0, 2, ssma2Buffer);
   if(values != 2){
      Print("Not enough data for ssma2");
      return;
   }
   
   values = CopyBuffer(ssma3Handle, 0, 0, 2, ssma3Buffer);
   if(values != 2){
      Print("Not enough data for ssma3");
      return;
   }
   
   values = CopyBuffer(ssmaH1Handle, 0, 0, 2, ssmaH1Buffer);
   if(values != 2){
      Print("Not enough data for ssmah1");
      return;
   }
   
   values = CopyBuffer(ssmaH2Handle, 0, 0, 2, ssmaH2Buffer);
   if(values != 2){
      Print("Not enough data for ssmah2");
      return;
   }
   
   values = CopyBuffer(ssmaH3Handle, 0, 0, 2, ssmaH3Buffer);
   if(values != 2){
      Print("Not enough data for ssmah3");
      return;
   }
   
   values = CopyBuffer(macdHandle, MAIN_LINE, 1, 2, macdLineBuffer);
   if(values != 2){
      Print("Not enough data for macd line");
      return;
   }
   
   values = CopyBuffer(macdHandle, SIGNAL_LINE, 1, 2, signalLineBuffer);
   if(values != 2){
      Print("Not enough data for signal line");
      return;
   }
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(ssmaH3Buffer[0] < ssmaH2Buffer[0] && ssmaH2Buffer[0] < ssmaH1Buffer[0])
   {
      if(ssma3Buffer[0] < ssma2Buffer[0] && ssma2Buffer[0] < ssma1Buffer[0] && ssma1Buffer[0] < ask)
      {
         if(macdLineBuffer[1] <= signalLineBuffer[1] && macdLineBuffer[0] > signalLineBuffer[0] && macdLineBuffer[0] < 0.0 && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0))
         {
            openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
            double sl = ask - SL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double tp = ask + TP * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            double SlForCalc = ask - sl;
            double lotSize;
            
            if(CalculateLots(SlForCalc, lotSize)){
               trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, ask, sl, tp, "Buy trade taken");
            }
         }
      }
   }
   
   if(ssmaH3Buffer[0] > ssmaH2Buffer[0] && ssmaH2Buffer[0] > ssmaH1Buffer[0])
   {
      if(ssma3Buffer[0] > ssma2Buffer[0] && ssma2Buffer[0] > ssma1Buffer[0] && ssma1Buffer[0] > bid)
      {
         if(macdLineBuffer[1] >= signalLineBuffer[1] && macdLineBuffer[0] < signalLineBuffer[0] && macdLineBuffer[0] > 0.0 && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0))
         {
            openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
            double sl = bid + SL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double tp = bid - TP * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            double SlForCalc = bid + sl;
            double lotSize;
            
            if(CalculateLots(SlForCalc, lotSize)){
               trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lotSize, bid, sl, tp, "Sell trade taken");
            }
         }
      }
   }
}