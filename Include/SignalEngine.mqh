//+------------------------------------------------------------------+
//| SignalEngine.mqh v2.0 — Motor de Sinais                          |
//| [FIX-1] Handles PERSISTENTES criados uma vez em Init()           |
//| [NEW-1] Filtro RSI(14): RSI>=40 compra / RSI<=60 venda           |
//| [NEW-2] MACD parametrizavel por simbolo (WIN != WDO)             |
//| [NEW-4] Filtro ATR: 70% da media 20 barras (era 50%)             |
//| [NEW-5] MACD histograma crescente (mais robusto)                 |
//+------------------------------------------------------------------+
#pragma once

enum ENUM_SIGNAL { SIGNAL_NONE = 0, SIGNAL_BUY = 1, SIGNAL_SELL = -1 };

struct STradeParams
  {
   double entry;
   double sl;
   double tp;
   double atr;
   double sl_dist_pts;
   double rsi;
   double macd_hist;
   double lote;
  };

class CSignalEngine
  {
private:
   int    m_hEmaR[2], m_hEmaL[2], m_hEmaT[2];
   int    m_hMacd[2], m_hAtr[2],  m_hRsi[2];
   string m_sym[2];
   int    m_emaR, m_emaL, m_emaT, m_atrP, m_rsiP;
   int    m_macdR[2], m_macdL[2], m_macdS[2];
   double m_atrMult, m_rr, m_atrFiltroPct;
   double m_rsiMin, m_rsiMax;

   int Idx(const string s) { return (s == m_sym[0]) ? 0 : 1; }

   double BufVal(int handle, int bufIdx, int shift)
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(handle, bufIdx, shift, 1, buf) <= 0) return 0;
      return buf[0];
     }

   double BufMedia(int handle, int n)
     {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(handle, 0, 0, n, buf) <= 0) return 0;
      double s = 0; for(int i=0;i<n;i++) s+=buf[i]; return s/n;
     }

public:
   bool Init(int emaR, int emaL, int emaT,
             int macdR0, int macdL0, int macdS0,
             int macdR1, int macdL1, int macdS1,
             int atrP, int rsiP,
             double atrMult, double rr, double atrFiltroPct,
             double rsiMin, double rsiMax,
             const string sym1, const string sym2)
     {
      m_sym[0]=sym1; m_sym[1]=sym2;
      m_emaR=emaR; m_emaL=emaL; m_emaT=emaT;
      m_atrP=atrP; m_rsiP=rsiP;
      m_atrMult=atrMult; m_rr=rr; m_atrFiltroPct=atrFiltroPct;
      m_rsiMin=rsiMin; m_rsiMax=rsiMax;
      m_macdR[0]=macdR0; m_macdL[0]=macdL0; m_macdS[0]=macdS0;
      m_macdR[1]=macdR1; m_macdL[1]=macdL1; m_macdS[1]=macdS1;

      for(int i=0;i<2;i++)
        {
         m_hEmaR[i]=iMA(m_sym[i],PERIOD_M5, m_emaR,0,MODE_EMA,PRICE_CLOSE);
         m_hEmaL[i]=iMA(m_sym[i],PERIOD_M5, m_emaL,0,MODE_EMA,PRICE_CLOSE);
         m_hEmaT[i]=iMA(m_sym[i],PERIOD_M15,m_emaT,0,MODE_EMA,PRICE_CLOSE);
         m_hMacd[i]=iMACD(m_sym[i],PERIOD_M5,m_macdR[i],m_macdL[i],m_macdS[i],PRICE_CLOSE);
         m_hAtr[i] =iATR(m_sym[i],PERIOD_M5, m_atrP);
         m_hRsi[i] =iRSI(m_sym[i],PERIOD_M5, m_rsiP,PRICE_CLOSE);
         if(m_hEmaR[i]==INVALID_HANDLE||m_hEmaL[i]==INVALID_HANDLE||
            m_hEmaT[i]==INVALID_HANDLE||m_hMacd[i]==INVALID_HANDLE||
            m_hAtr[i] ==INVALID_HANDLE||m_hRsi[i] ==INVALID_HANDLE)
           { Print("[SignalEngine] ERRO handles para ",m_sym[i]); return false; }
        }
      Print("[SignalEngine] Handles criados: ",sym1," e ",sym2);
      return true;
     }

   void Deinit()
     {
      for(int i=0;i<2;i++)
        {
         IndicatorRelease(m_hEmaR[i]); IndicatorRelease(m_hEmaL[i]);
         IndicatorRelease(m_hEmaT[i]); IndicatorRelease(m_hMacd[i]);
         IndicatorRelease(m_hAtr[i]);  IndicatorRelease(m_hRsi[i]);
        }
     }

   double GetATR(const string sym)
     { return BufVal(m_hAtr[Idx(sym)], 0, 1); }

   ENUM_SIGNAL GetSinal(const string sym)
     {
      int    i      = Idx(sym);
      double emaR0  = BufVal(m_hEmaR[i],0,0), emaR1=BufVal(m_hEmaR[i],0,1);
      double emaL0  = BufVal(m_hEmaL[i],0,0), emaL1=BufVal(m_hEmaL[i],0,1);
      double emaT   = BufVal(m_hEmaT[i],0,0);
      double macdH0 = BufVal(m_hMacd[i],1,0), macdH1=BufVal(m_hMacd[i],1,1);
      double atr    = BufVal(m_hAtr[i], 0,0);
      double atrMed = BufMedia(m_hAtr[i], 20);
      double rsi    = BufVal(m_hRsi[i], 0,0);
      double preco  = SymbolInfoDouble(sym, SYMBOL_LAST);

      if(emaR0==0||emaL0==0||emaT==0||atr==0||atrMed==0||rsi==0) return SIGNAL_NONE;
      // [NEW-4] Filtro ATR: 70% da media
      if(atr < atrMed * m_atrFiltroPct) return SIGNAL_NONE;

      bool crossUp   = (emaR1<=emaL1)&&(emaR0>emaL0);
      bool crossDown = (emaR1>=emaL1)&&(emaR0<emaL0);
      bool tendUp    = preco > emaT;
      bool tendDown  = preco < emaT;
      // [NEW-5] MACD histograma positivo E crescendo
      bool macdBull  = (macdH0>0)&&(macdH0>macdH1);
      bool macdBear  = (macdH0<0)&&(macdH0<macdH1);
      // [NEW-1] Filtro RSI
      bool rsiOkBuy  = rsi>=m_rsiMin && rsi<=70.0;
      bool rsiOkSell = rsi<=m_rsiMax && rsi>=30.0;

      if(crossUp   && tendUp   && macdBull && rsiOkBuy)  return SIGNAL_BUY;
      if(crossDown && tendDown && macdBear && rsiOkSell) return SIGNAL_SELL;
      return SIGNAL_NONE;
     }

   bool GetTradeParams(const string sym, ENUM_SIGNAL sinal, STradeParams &p, double lote)
     {
      int    i   = Idx(sym);
      int    dig = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double tick= SymbolInfoDouble(sym, SYMBOL_POINT);
      double atr = GetATR(sym);
      if(atr<=0) return false;
      double slDist=atr*m_atrMult, tpDist=slDist*m_rr;
      p.atr=atr; p.sl_dist_pts=slDist/tick;
      p.rsi=BufVal(m_hRsi[i],0,0); p.macd_hist=BufVal(m_hMacd[i],1,0); p.lote=lote;
      if(sinal==SIGNAL_BUY)
        { p.entry=ask; p.sl=NormalizeDouble(ask-slDist,dig); p.tp=NormalizeDouble(ask+tpDist,dig); }
      else
        { p.entry=bid; p.sl=NormalizeDouble(bid+slDist,dig); p.tp=NormalizeDouble(bid-tpDist,dig); }
      return true;
     }
  };
//+------------------------------------------------------------------+