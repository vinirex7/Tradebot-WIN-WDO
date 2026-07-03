//+------------------------------------------------------------------+
//|  SignalEngine.mqh — Motor de Sinais DualTrendScalper            |
//|  EMA 9/21 M5 + EMA 50 M15 + MACD + ATR/volatilidade             |
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
   double atr_mult_used;
};

class CSignalEngine
{
private:
   int    m_h_ema_r[2];
   int    m_h_ema_l[2];
   int    m_h_ema_t[2];
   int    m_h_macd[2];
   int    m_h_atr[2];

   int    m_ema_r, m_ema_l, m_ema_t;
   int    m_macd_r, m_macd_l, m_macd_s;
   int    m_atr_p;
   double m_atr_mult_win;
   double m_atr_mult_wdo;
   double m_rr;
   double m_atr_min_ratio;

   string m_sym[2];

   int IdxSym(const string s)
   {
      if(s == m_sym[0]) return 0;
      if(s == m_sym[1]) return 1;
      return -1;
   }

   double AtrMultForIndex(const int i)
   {
      return i == 1 ? m_atr_mult_wdo : m_atr_mult_win;
   }

public:
   bool Init(const string sym1, const string sym2,
             int ema_r, int ema_l, int ema_t,
             int macd_r, int macd_l, int macd_s,
             int atr_p, double atr_mult_win, double atr_mult_wdo,
             double rr, double atr_min_ratio)
   {
      m_sym[0] = sym1;
      m_sym[1] = sym2;

      m_ema_r = ema_r; m_ema_l = ema_l; m_ema_t = ema_t;
      m_macd_r = macd_r; m_macd_l = macd_l; m_macd_s = macd_s;
      m_atr_p = atr_p;
      m_atr_mult_win = atr_mult_win;
      m_atr_mult_wdo = atr_mult_wdo;
      m_rr = rr;
      m_atr_min_ratio = atr_min_ratio;

      for(int i = 0; i < 2; i++)
      {
         SymbolSelect(m_sym[i], true);
         m_h_ema_r[i] = iMA(m_sym[i], PERIOD_M5,  m_ema_r, 0, MODE_EMA, PRICE_CLOSE);
         m_h_ema_l[i] = iMA(m_sym[i], PERIOD_M5,  m_ema_l, 0, MODE_EMA, PRICE_CLOSE);
         m_h_ema_t[i] = iMA(m_sym[i], PERIOD_M15, m_ema_t, 0, MODE_EMA, PRICE_CLOSE);
         m_h_macd[i]  = iMACD(m_sym[i], PERIOD_M5, m_macd_r, m_macd_l, m_macd_s, PRICE_CLOSE);
         m_h_atr[i]   = iATR(m_sym[i], PERIOD_M5,  m_atr_p);

         if(m_h_ema_r[i] == INVALID_HANDLE || m_h_ema_l[i] == INVALID_HANDLE ||
            m_h_ema_t[i] == INVALID_HANDLE || m_h_macd[i]  == INVALID_HANDLE ||
            m_h_atr[i]   == INVALID_HANDLE)
         {
            Print("ERRO: Falha ao criar indicadores para ", m_sym[i]);
            return false;
         }
      }
      return true;
   }

   void Deinit()
   {
      for(int i = 0; i < 2; i++)
      {
         IndicatorRelease(m_h_ema_r[i]);
         IndicatorRelease(m_h_ema_l[i]);
         IndicatorRelease(m_h_ema_t[i]);
         IndicatorRelease(m_h_macd[i]);
         IndicatorRelease(m_h_atr[i]);
      }
   }

   double GetATR(const string sym)
   {
      int i = IdxSym(sym);
      if(i < 0) return 0;
      double buf[1];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_h_atr[i], 0, 1, 1, buf) <= 0) return 0;
      return buf[0];
   }

   bool VolatilidadeOK(const int i, double &atr_atual, double &atr_media)
   {
      double atr_buf[20];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_h_atr[i], 0, 1, 20, atr_buf) < 20) return false;

      atr_atual = atr_buf[0];
      atr_media = 0.0;
      for(int k = 0; k < 20; k++) atr_media += atr_buf[k];
      atr_media /= 20.0;

      if(atr_atual <= 0 || atr_media <= 0) return false;
      return atr_atual >= atr_media * m_atr_min_ratio;
   }

   ENUM_SIGNAL GetSinal(const string sym)
   {
      int i = IdxSym(sym);
      if(i < 0) return SIGNAL_NONE;

      double ema_r[2], ema_l[2], ema_t[1], macd_m[2], macd_s[2];
      ArraySetAsSeries(ema_r,  true);
      ArraySetAsSeries(ema_l,  true);
      ArraySetAsSeries(ema_t,  true);
      ArraySetAsSeries(macd_m, true);
      ArraySetAsSeries(macd_s, true);

      if(CopyBuffer(m_h_ema_r[i], 0, 1, 2, ema_r)  <= 0) return SIGNAL_NONE;
      if(CopyBuffer(m_h_ema_l[i], 0, 1, 2, ema_l)  <= 0) return SIGNAL_NONE;
      if(CopyBuffer(m_h_ema_t[i], 0, 1, 1, ema_t)  <= 0) return SIGNAL_NONE;
      if(CopyBuffer(m_h_macd[i],  MAIN_LINE,   1, 2, macd_m) <= 0) return SIGNAL_NONE;
      if(CopyBuffer(m_h_macd[i],  SIGNAL_LINE, 1, 2, macd_s) <= 0) return SIGNAL_NONE;

      double atr_atual, atr_media;
      if(!VolatilidadeOK(i, atr_atual, atr_media)) return SIGNAL_NONE;

      double preco = SymbolInfoDouble(sym, SYMBOL_LAST);
      if(preco <= 0) preco = SymbolInfoDouble(sym, SYMBOL_BID);

      bool crossUp   = ema_r[1] <= ema_l[1] && ema_r[0] > ema_l[0];
      bool crossDown = ema_r[1] >= ema_l[1] && ema_r[0] < ema_l[0];
      bool tendUp    = preco > ema_t[0];
      bool tendDown  = preco < ema_t[0];
      bool macdBull  = macd_m[0] > macd_s[0];
      bool macdBear  = macd_m[0] < macd_s[0];

      if(crossUp   && tendUp   && macdBull) return SIGNAL_BUY;
      if(crossDown && tendDown && macdBear) return SIGNAL_SELL;

      return SIGNAL_NONE;
   }

   bool GetTradeParams(const string sym, ENUM_SIGNAL sinal, STradeParams &p)
   {
      int i = IdxSym(sym);
      if(i < 0) return false;

      int    dig       = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double bid       = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask       = SymbolInfoDouble(sym, SYMBOL_ASK);
      double atr_now, atr_avg;

      if(!VolatilidadeOK(i, atr_now, atr_avg)) return false;
      if(tick_size <= 0) tick_size = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(tick_size <= 0) return false;

      double slDist = atr_now * AtrMultForIndex(i);
      double tpDist = slDist * m_rr;

      if(sinal == SIGNAL_BUY)
      {
         p.entry = ask;
         p.sl    = NormalizeDouble(ask - slDist, dig);
         p.tp    = NormalizeDouble(ask + tpDist, dig);
      }
      else
      {
         p.entry = bid;
         p.sl    = NormalizeDouble(bid + slDist, dig);
         p.tp    = NormalizeDouble(bid - tpDist, dig);
      }

      p.atr           = atr_now;
      p.sl_dist_pts   = slDist;
      p.atr_mult_used = AtrMultForIndex(i);
      return true;
   }
};
