//+------------------------------------------------------------------+
//|  TimeFilter.mqh — Filtro de Horário DualTrendScalper            |
//|  Janelas: 9h30-12h e 14h-16h30 | Fechamento: 18h10             |
//+------------------------------------------------------------------+
#pragma once

class CTimeFilter
{
private:
   int m_h1_ini, m_m1_ini, m_h1_fim, m_m1_fim;
   int m_h2_ini, m_m2_ini, m_h2_fim, m_m2_fim;
   int m_h_fech, m_m_fech;

   int ToMinutes(int h, int m) { return h * 60 + m; }

public:
   void Init(int h1i, int m1i, int h1f, int m1f,
             int h2i, int m2i, int h2f, int m2f,
             int hf,  int mf)
   {
      m_h1_ini = h1i; m_m1_ini = m1i;
      m_h1_fim = h1f; m_m1_fim = m1f;
      m_h2_ini = h2i; m_m2_ini = m2i;
      m_h2_fim = h2f; m_m2_fim = m2f;
      m_h_fech = hf;  m_m_fech = mf;
   }

   bool DentroJanela()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int agora = ToMinutes(dt.hour, dt.min);

      int j1_ini = ToMinutes(m_h1_ini, m_m1_ini);
      int j1_fim = ToMinutes(m_h1_fim, m_m1_fim);
      int j2_ini = ToMinutes(m_h2_ini, m_m2_ini);
      int j2_fim = ToMinutes(m_h2_fim, m_m2_fim);

      return (agora >= j1_ini && agora < j1_fim) ||
             (agora >= j2_ini && agora < j2_fim);
   }

   bool DeveFechamento()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int agora  = ToMinutes(dt.hour, dt.min);
      int fecham = ToMinutes(m_h_fech, m_m_fech);
      return agora >= fecham;
   }
};
