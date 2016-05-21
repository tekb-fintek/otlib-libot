/*-                                                     -*- c++ -*-
 * Copyright (c) 2016
 * Sean Champ. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met: 
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials provided
 *    with the distribution. 
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.  
 *
 */

 
#property copyright "Sean Champ"
#property link      "http://onename.com/spchamp"
#property description "OTLIB"
#property version   "1.00"
#property strict
#property script_show_inputs



//--- input parameters
input int   a_period_init=5; // e.g STO//D, STO//SLOWING
input int   b_period_init=15; // e.g STO//K, CCI PERIOD, FISHER PERIOD
input int   c_period_init=10; // e.g LWMA period
input int   min_trend_period = 3; // minimum number of clock ticks for trend calculation

// OTLIB

// - curency pairs

string getCurrentSymbol() {
   return ChartSymbol(0);
}

// - interactive messaging 

int errorNotify(const string message) {
   Print(message);
   return MessageBox(message,"Error",MB_OKCANCEL);
}

int msgOkAbort(const string message) {

    Print(message);
    
    int retv = IDOK; // NOT DEBUG BUILD
    // DEBUG BUILD      
    /* int retv = MessageBox(message, "Notifiation", MB_OKCANCEL); // DEBUG BUILD
       if (retv == IDCANCEL) {
         ExpertRemove();
       }
    */
    
   return retv;
}

// - charts

// - market information

// See also: SymbolInfoDouble(Symbol(),SYMBOL_{ASK|BID});


double getAskP(){ // market ask price, current chart and symbol
   string symbol = getCurrentSymbol();
   return getAskPForS(symbol);
}


double getAskPForC(const long id){ 
   // return ask price for chart with specified chart ID. 
   // ID 0 indicates current chart
   string symbol = ChartSymbol(id);
   return getAskPForS(symbol);
}


double getAskPForS(const string symbol){
   return MarketInfo(symbol,MODE_ASK);
}


double getOfferP(){ // market offer price, i.e bid price
   string symbol = getCurrentSymbol();
   return getOfferPForS(symbol);
}


double getOfferPForC(const long id){ 
   // return offer price for chart with specified chart ID. 
   // ID 0 indicates current chart
   string symbol = ChartSymbol(id);
   return getOfferPForS(symbol);
}


double getOfferPForS(const string symbol){
   return MarketInfo(symbol,MODE_BID);
}


double getSpread() { // diference of ask and offer price
   string symbol = getCurrentSymbol();
   return getSpreadForS(symbol);
}


double getSpreadForC(const long id){ 
   // return market spread for chart with specified chart ID. 
   // ID 0 indicates current chart
   string symbol = ChartSymbol(id);
   return getSpreadForS(symbol);
}


double getSpreadForS(const string symbol) {
   double ask = getAskPForS(symbol);
   double offer = getOfferPForS(symbol);
   return ask - offer;
}

// -- market performance data

class Trend { // FIXME: separate this into four buffers, two of datetime[] and two of double[]
public:
   datetime startTime;
   datetime endTime;
   double startRate;
   double endRate;
      Trend() ;
      Trend(datetime time, double rate);
      Trend(datetime t1, double r1, datetime t2, double r2);
};

Trend::Trend() {
  startTime = 0;
  startRate = 0;
  endTime = 0;
  endRate = 0; 
}

Trend::Trend(datetime time, double rate) {
  startRate = 0;
  startTime = 0;
  endTime = time;
  endRate = rate; 
}

Trend::Trend(datetime t1, double r1, datetime t2, double r2) {
   startRate = r1;
   startTime = t1;
   endRate = r2;
   endTime = t2;
}

double getChange(const Trend &trend) {
   return (trend.endRate - trend.startRate);
}




double calcRate(double open, double high, double low, double close) {
   double value = ( open + high + low + close ) / 4;
   // double value = (high + low) / 2;
   // double value = (open + close) / 2;
   return value;
}

// NB: see also SymbolInfoTick()

int calcTrends(const int count, 
                  const int start, 
                  Trend* &trends[],
                  const double &open[],
                  const double &high[],
                  const double &low[],
                  const double &close[],
                  const datetime &time[]) {
   // traverse {open, high, low, close, time} arrays for a duration 
   // of `count` beginning at `start`. Calculate time and rate of 
   // beginnings of market trend reversals, storing that data in 
   // the `trends` array and returning the number of trends calculated.
   //
   // `trends` should be of a length no greater than the length of each
   // of the {open, high, low, close, time} arrays

   int nrTrends;
   double rate, sRate, pRate;
   datetime sTime;
   bool calcMax = false;

   nrTrends = 0;

   sRate = calcRate(open[start], high[start], low[start], close[start]);
   pRate = sRate;
   sTime = time[start];

   for(int n=start; n < count; n++) {
      rate = calcRate(open[n], high[n], low[n], close[n]);
      if (rate > pRate && calcMax) {
      // continuing trend rate > pRate > sRate
         pRate = rate;
      } else if (rate <= pRate && !calcMax) {
      // continuing trend rate <= pRate <= sRate
         pRate = rate;
      } else if ( (calcMax && rate <= pRate) ||
                  (!calcMax && rate > pRate) ) { 
      // trend interrupted
           trends[nrTrends++] = new Trend(sTime, sRate, time[n-1], pRate);
           sRate = pRate;
           pRate = rate;
           sTime = time[n-1];
           msgOkAbort("Trend mark: " + sTime);
           calcMax = (pRate > sRate); // reset
      }
   }

   return nrTrends;
}

void drawTrendsForS(const long id, const Trend* &trends[], const int count) {
   // FIXME: Cleanups - function name
   datetime startT, endT;
   double startP, endP;
   bool start, end;
   string name;

   for (int n = 0; n < count; n++) {
      startT = trends[n].startTime;
      startP = trends[n].startRate;
      if (startT != 0 && startP != 0) {
         start = true;
         name = "TREND START " + startT + " " + MathRand(); // FIXME
         ObjectCreate(id,name, OBJ_VLINE, 0, startT, 0);
      }
      
      endT = trends[n].endTime;
      endP = trends[n].endRate;
      if (endT != 0 && endP != 0) {
         end = true;
         name = "TREND END " + endT + " " + MathRand(); // FIXME
         ObjectCreate(id,name, OBJ_VLINE, 0, endT, 0);
      }
      
      if(start && end) {
         name = "TREND LINE " + MathRand(); // FIXME
         ObjectCreate(id, name, OBJ_TREND, 0, startT, startP, endT, endP);
         ObjectSetInteger(id,name,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(id,name,OBJPROP_COLOR,clrLime); // FIME: MAKE PROPERTY
         ObjectSetInteger(id,name,OBJPROP_WIDTH,3); // FIME: MAKE PROPERTY
      } else {
         Print("Trend not complete : [" + startT + " ... " + endT + "]");
      }
   }
}

// see also: Heikin Ashi.mq4 src - "Existing work" in MQL4 indicator development

void OnStart() {
   // run program in script mode (DEBUG)
   
   // DEBUG
   ObjectsDeleteAll(0,-1);
   msgOkAbort("Visible : " + CHART_VISIBLE_BARS); // DEBUG INFO
   
   // const string symbol = getCurrentSymbol();
   
   int count=CHART_VISIBLE_BARS;
   Trend *trends[CHART_VISIBLE_BARS]; // ... can't specify 'count' for eval as an index value (MQL4)
   
   // use buffered Open, High, Low, Close, Time instead of CopyRates(...)
   // RefreshRates();
   const int nrTrends = calcTrends(count, 0, trends, Open, High, Low, Close, Time); // 15 instead of rates_total
   
   // MessageBox("Rate: " + DoubleToString(last.startRate),"Notification",MB_OK); // DEBUG INFO
   
   drawTrendsForS(ChartID(), trends, nrTrends); // DEBUG INFO
   
   ExpertRemove(); // DEBUG
   
}

/*

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
   // run program in indicator mode

   // NB: ensure open, high, low, close, time all ArraySetAsSeries(it, true) - see also Time[] docu

   initOHLC(false, open, high, low, close); // true ??  the documentation seems inconsistent

   MessageBox("Visible : " + CHART_VISIBLE_BARS, "Notification", MB_OK); // DEBUG INFO
   
   string symbol = getCurrentSymbol();
   Trend *last = calcTrendsForS(symbol,PERIOD_M1, 15, 0, open, high, low, close); // 15 instead of rates_total
   MessageBox("Rate: " + DoubleToString(last.startRate),"Notification",MB_OK); // DEBUG INFO
   
   drawTrendsForS(symbol, last); // DEBUG INFO
   
   ExpertRemove(); // DEBUG
   return 0; // DEBUG
}

*/