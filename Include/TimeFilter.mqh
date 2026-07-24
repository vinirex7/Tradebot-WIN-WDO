//+------------------------------------------------------------------+
//| TimeFilter.mqh v2.0 — Filtro de Horario                          |
//| [NEW-3] Janelas de horario INDEPENDENTES por simbolo             |
//+------------------------------------------------------------------+
#pragma once

class CTimeFilter
  {
private:
   int    m_h1i[2], m_m1i[2], m_h1f[2], m_m1f[2];
   int    m_h2i[2], m_m2i[2], m_h2f[2], m_m2f[2];
   int    m_hFech, m_mFech;
   string m_sym[2];

   int ToMin(int h, int m) { return h * 60 + m; }
   int Idx(const string s) { return (s == m_sym[0]) ? 0 : 1; }

public:
   void SetSimbolos(const string sym1, const string sym2)
     { m_sym[0] = sym1; m_sym[1] = sym2; }

   // idx = 0 (WIN) ou 1 (WDO)
   void InitJanela(int idx,
                   int h1i, int m1i, int h1f, int m1f,
                   int h2i, int m2i, int h2f, int m2f)
     {
      m_h1i[idx]=h1i; m_m1i[idx]=m1i; m_h1f[idx]=h1f; m_m1f[idx]=m1f;
      m_h2i[idx]=h2i; m_m2i[idx]=m2i; m_h2f[idx]=h2f; m_m2f[idx]=m2f;
     }

   void InitFechamento(int h, int m) { m_hFech = h; m_mFech = m; }

   bool DentroJanela(const string sym)
     {
      int i = Idx(sym);
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int agora = ToMin(dt.hour, dt.min);
      return (agora >= ToMin(m_h1i[i],m_m1i[i]) && agora < ToMin(m_h1f[i],m_m1f[i])) ||
             (agora >= ToMin(m_h2i[i],m_m2i[i]) && agora < ToMin(m_h2f[i],m_m2f[i]));
     }

   bool DeveFechamento()
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return ToMin(dt.hour, dt.min) >= ToMin(m_hFech, m_mFech);
     }
  };
//+------------------------------------------------------------------+