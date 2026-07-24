//+------------------------------------------------------------------+
//| TradeLogger.mqh v2.0 — Logger CSV Estruturado                    |
//| [NEW-6] Log completo por operacao: entrada, SL, TP, ATR, RSI,   |
//|         MACD, lote, risco calculado, resultado                  |
//+------------------------------------------------------------------+
#pragma once

class CTradeLogger
  {
private:
   string m_fileBase;
   int    m_handle;
   long   m_magic;

   void AbrirArquivo()
     {
      string data = TimeToString(TimeCurrent(), TIME_DATE);
      StringReplace(data, ".", "-");
      string fname = m_fileBase + "_" + data + ".csv";
      m_handle = FileOpen(fname, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ';');
      if(m_handle == INVALID_HANDLE)
        { Print("[TradeLogger] Erro ao abrir ", fname); return; }
      if(FileSize(m_handle) == 0)
         FileWrite(m_handle,
            "DataHora","Simbolo","Direcao","Entrada","SL","TP",
            "ATR","RSI","MACD_Hist","Lote","RiscoCalc_R","Resultado_R","Status");
      FileSeek(m_handle, 0, SEEK_END);
     }

public:
   void Init(const string fileBase, long magic)
     { m_fileBase=fileBase; m_magic=magic; m_handle=INVALID_HANDLE; AbrirArquivo(); }

   void NovoDia() { Flush(); AbrirArquivo(); }

   void LogTrade(const string sym, const string direcao,
                 double entrada, double sl, double tp,
                 double atr, double rsi, double macdHist,
                 double lote, double riscoCalc)
     {
      if(m_handle==INVALID_HANDLE) return;
      FileWrite(m_handle,
         TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),
         sym, direcao,
         DoubleToString(entrada,_Digits), DoubleToString(sl,_Digits), DoubleToString(tp,_Digits),
         DoubleToString(atr,2), DoubleToString(rsi,2), DoubleToString(macdHist,5),
         DoubleToString(lote,2), DoubleToString(riscoCalc,2), "", "ABERTA");
      FileFlush(m_handle);
     }

   void LogDeal(ulong ticket)
     {
      if(m_handle==INVALID_HANDLE) return;
      string sym   = HistoryDealGetString(ticket, DEAL_SYMBOL);
      long   tipo  = HistoryDealGetInteger(ticket, DEAL_TYPE);
      double preco = HistoryDealGetDouble(ticket, DEAL_PRICE);
      double pnl   = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      string dir   = (tipo==DEAL_TYPE_BUY) ? "BUY" : "SELL";
      FileWrite(m_handle,
         TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),
         sym, dir, DoubleToString(preco,_Digits),
         "","","","","","","", DoubleToString(pnl,2), "FECHADA");
      FileFlush(m_handle);
     }

   void LogMensagem(const string msg)
     {
      if(m_handle==INVALID_HANDLE) return;
      FileWrite(m_handle, TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),
         "","INFO","","","","","","","","",msg,"");
      FileFlush(m_handle);
     }

   void Flush()
     {
      if(m_handle!=INVALID_HANDLE)
        { FileFlush(m_handle); FileClose(m_handle); m_handle=INVALID_HANDLE; }
     }
  };
//+------------------------------------------------------------------+