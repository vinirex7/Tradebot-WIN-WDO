//+------------------------------------------------------------------+
//|  TimeFilter.mqh — Filtros de janela horária B3                  |
//+------------------------------------------------------------------+
#pragma once

class CTimeFilter
{
private:
   int m_h1s,m_m1s,m_h1e,m_m1e;
   int m_h2s,m_m2s,m_h2e,m_m2e;
   int m_hFech,m_mFech;

public:
   void Init(int h1s,int m1s,int h1e,int m1e,
             int h2s,int m2s,int h2e,int m2e,
             int hFech,int mFech)
   {
      m_h1s=h1s;m_m1s=m1s;m_h1e=h1e;m_m1e=m1e;
      m_h2s=h2s;m_m2s=m2s;m_h2e=h2e;m_m2e=m2e;
      m_hFech=hFech;m_mFech=mFech;
   }

   bool DentroJanela() const
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
      int agora=dt.hour*60+dt.min;
      bool j1=(agora>=m_h1s*60+m_m1s)&&(agora<m_h1e*60+m_m1e);
      bool j2=(agora>=m_h2s*60+m_m2s)&&(agora<m_h2e*60+m_m2e);
      return j1||j2;
   }

   bool DeveFechamento() const
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
      return(dt.hour*60+dt.min >= m_hFech*60+m_mFech);
   }
};
