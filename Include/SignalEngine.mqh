//+------------------------------------------------------------------+
//|  SignalEngine.mqh — Motor de sinais EMA + MACD + ATR            |
//+------------------------------------------------------------------+
#pragma once

enum ENUM_SIGNAL { SIGNAL_NONE = 0, SIGNAL_BUY = 1, SIGNAL_SELL = -1 };

struct STradeParams
{
   double entry;
   double sl;
   double tp;
   double sl_dist_pts;
   double atr;
};

class CSignalEngine
{
private:
   int    m_ema_r, m_ema_l, m_ema_t;
   int    m_macd_f, m_macd_s, m_macd_sig;
   int    m_atr_per;
   double m_atr_mult_sl;
   double m_rr_ratio;
   int    m_hEmaR_WIN, m_hEmaL_WIN, m_hEmaT_WIN, m_hMACD_WIN, m_hATR_WIN;
   int    m_hEmaR_WDO, m_hEmaL_WDO, m_hEmaT_WDO, m_hMACD_WDO, m_hATR_WDO;
   string m_sym1, m_sym2;

   bool GetHandles(const string sym, int &hR, int &hL, int &hT, int &hM, int &hA)
   {
      hR = iMA(sym, PERIOD_M5,  m_ema_r, 0, MODE_EMA, PRICE_CLOSE);
      hL = iMA(sym, PERIOD_M5,  m_ema_l, 0, MODE_EMA, PRICE_CLOSE);
      hT = iMA(sym, PERIOD_M15, m_ema_t, 0, MODE_EMA, PRICE_CLOSE);
      hM = iMACD(sym, PERIOD_M5, m_macd_f, m_macd_s, m_macd_sig, PRICE_CLOSE);
      hA = iATR(sym, PERIOD_M5, m_atr_per);
      return(hR != INVALID_HANDLE && hL != INVALID_HANDLE &&
             hT != INVALID_HANDLE && hM != INVALID_HANDLE && hA != INVALID_HANDLE);
   }

   double BufVal(int handle, int buf, int shift)
   {
      double arr[];
      ArraySetAsSeries(arr, true);
      if(CopyBuffer(handle, buf, shift, 1, arr) <= 0) return 0.0;
      return arr[0];
   }

   bool GetHandlesForSym(const string sym, int &hR, int &hL, int &hT, int &hM, int &hA)
   {
      if(sym == m_sym1){ hR=m_hEmaR_WIN; hL=m_hEmaL_WIN; hT=m_hEmaT_WIN; hM=m_hMACD_WIN; hA=m_hATR_WIN; return true; }
      if(sym == m_sym2){ hR=m_hEmaR_WDO; hL=m_hEmaL_WDO; hT=m_hEmaT_WDO; hM=m_hMACD_WDO; hA=m_hATR_WDO; return true; }
      return false;
   }

public:
   bool Init(int emaR, int emaL, int emaT, int macdF, int macdS, int macdSig,
             int atrPer, double atrMult, double rrRatio)
   {
      m_ema_r=emaR; m_ema_l=emaL; m_ema_t=emaT;
      m_macd_f=macdF; m_macd_s=macdS; m_macd_sig=macdSig;
      m_atr_per=atrPer; m_atr_mult_sl=atrMult; m_rr_ratio=rrRatio;
      m_sym1="WINFUT"; m_sym2="WDOFUT";
      if(!GetHandles(m_sym1, m_hEmaR_WIN, m_hEmaL_WIN, m_hEmaT_WIN, m_hMACD_WIN, m_hATR_WIN))
      { Print("ERRO handles ", m_sym1); return false; }
      if(!GetHandles(m_sym2, m_hEmaR_WDO, m_hEmaL_WDO, m_hEmaT_WDO, m_hMACD_WDO, m_hATR_WDO))
      { Print("ERRO handles ", m_sym2); return false; }
      return true;
   }

   void Deinit()
   {
      int h[] = {m_hEmaR_WIN,m_hEmaL_WIN,m_hEmaT_WIN,m_hMACD_WIN,m_hATR_WIN,
                 m_hEmaR_WDO,m_hEmaL_WDO,m_hEmaT_WDO,m_hMACD_WDO,m_hATR_WDO};
      for(int i=0;i<ArraySize(h);i++) if(h[i]!=INVALID_HANDLE) IndicatorRelease(h[i]);
   }

   ENUM_SIGNAL GetSinal(const string sym)
   {
      int hR,hL,hT,hM,hA;
      if(!GetHandlesForSym(sym,hR,hL,hT,hM,hA)) return SIGNAL_NONE;

      double emaR_cur  = BufVal(hR,0,0), emaR_prev = BufVal(hR,0,1);
      double emaL_cur  = BufVal(hL,0,0), emaL_prev = BufVal(hL,0,1);
      double emaT      = BufVal(hT,0,0);
      double macd_main = BufVal(hM,0,0), macd_sig  = BufVal(hM,1,0);
      double atr       = BufVal(hA,0,0);
      if(emaR_cur==0||emaL_cur==0||atr==0) return SIGNAL_NONE;

      double ask = SymbolInfoDouble(sym,SYMBOL_ASK);
      double bid = SymbolInfoDouble(sym,SYMBOL_BID);

      double atrArr[]; ArraySetAsSeries(atrArr,true);
      CopyBuffer(hA,0,0,20,atrArr);
      double atrMed=0; for(int i=0;i<20;i++) atrMed+=atrArr[i]; atrMed/=20.0;
      if(atr < atrMed*0.5) return SIGNAL_NONE;

      bool cruzeAlta  = (emaR_prev < emaL_prev) && (emaR_cur > emaL_cur);
      bool cruzeBaixa = (emaR_prev > emaL_prev) && (emaR_cur < emaL_cur);
      bool tendAlta   = ask > emaT;
      bool tendBaixa  = bid < emaT;
      bool macdPos    = (macd_main - macd_sig) > 0;
      bool macdNeg    = (macd_main - macd_sig) < 0;

      if(cruzeAlta  && tendAlta  && macdPos) return SIGNAL_BUY;
      if(cruzeBaixa && tendBaixa && macdNeg) return SIGNAL_SELL;
      return SIGNAL_NONE;
   }

   bool GetTradeParams(const string sym, ENUM_SIGNAL sinal, STradeParams &p)
   {
      int hR,hL,hT,hM,hA;
      if(!GetHandlesForSym(sym,hR,hL,hT,hM,hA)) return false;
      double atr   = BufVal(hA,0,0);
      double pt    = SymbolInfoDouble(sym,SYMBOL_POINT);
      double ask   = SymbolInfoDouble(sym,SYMBOL_ASK);
      double bid   = SymbolInfoDouble(sym,SYMBOL_BID);
      int    dig   = (int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
      double slDist = atr*m_atr_mult_sl;
      double tpDist = slDist*m_rr_ratio;
      p.atr = atr;
      if(sinal==SIGNAL_BUY)
      { p.entry=ask; p.sl=NormalizeDouble(ask-slDist,dig); p.tp=NormalizeDouble(ask+tpDist,dig); p.sl_dist_pts=slDist/pt; }
      else
      { p.entry=bid; p.sl=NormalizeDouble(bid+slDist,dig); p.tp=NormalizeDouble(bid-tpDist,dig); p.sl_dist_pts=slDist/pt; }
      double spread = SymbolInfoInteger(sym,SYMBOL_SPREAD)*pt;
      if(tpDist <= spread*3) return false;
      return true;
   }

   double GetATR(const string sym)
   {
      int hR,hL,hT,hM,hA;
      if(!GetHandlesForSym(sym,hR,hL,hT,hM,hA)) return 0.0;
      return BufVal(hA,0,0);
   }
};
