//+------------------------------------------------------------------+
//|  TradeLogger.mqh — Logger de Trades DualTrendScalper           |
//|  Grava CSV em MQL5/Files/                                       |
//+------------------------------------------------------------------+
#pragma once

class CTradeLogger
{
private:
   string m_file;
   int    m_handle;
   long   m_magic;

public:
   void Init(const string base, long magic)
   {
      m_magic = magic;
      m_file  = base + "_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
      m_file  = StringReplace(m_file, ".", "-") == 0 ? m_file : m_file;

      m_handle = FileOpen(m_file, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
      if(m_handle == INVALID_HANDLE)
      {
         Print("Logger: nao foi possivel abrir arquivo: ", m_file);
         return;
      }
      FileWrite(m_handle, "DateTime","Mensagem");
      Print("Logger iniciado: ", m_file);
   }

   void LogTrade(const string msg)
   {
      if(m_handle == INVALID_HANDLE) return;
      FileWrite(m_handle, TimeToString(TimeCurrent()), msg);
   }

   void LogDeal(ulong ticket, double profit)
   {
      if(m_handle == INVALID_HANDLE) return;
      string sym    = HistoryDealGetString(ticket, DEAL_SYMBOL);
      long   tipo   = HistoryDealGetInteger(ticket, DEAL_TYPE);
      double preco  = HistoryDealGetDouble(ticket, DEAL_PRICE);
      string dir    = (tipo == DEAL_TYPE_BUY) ? "BUY" : "SELL";
      string msg    = StringFormat("DEAL|%s|%s|%.2f|PNL:%.2f",
                      sym, dir, preco, profit);
      FileWrite(m_handle, TimeToString(TimeCurrent()), msg);
   }

   void LogDiaSeparator(const string data)
   {
      if(m_handle == INVALID_HANDLE) return;
      // Reabrir arquivo com data nova
      FileClose(m_handle);
      string novo = StringSubstr(m_file, 0, StringLen(m_file)-14) +
                    data + ".csv";
      m_file   = novo;
      m_handle = FileOpen(m_file, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
      if(m_handle != INVALID_HANDLE)
         FileWrite(m_handle, "DateTime","Mensagem");
   }

   void Flush()
   {
      if(m_handle != INVALID_HANDLE)
      {
         FileFlush(m_handle);
         FileClose(m_handle);
         m_handle = INVALID_HANDLE;
      }
   }
};
