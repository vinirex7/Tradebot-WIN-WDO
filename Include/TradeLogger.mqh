//+------------------------------------------------------------------+
//|  TradeLogger.mqh — Registro CSV de operações                   |
//+------------------------------------------------------------------+
#pragma once

class CTradeLogger
{
private:
   int    m_handle;
   string m_filename;
   long   m_magic;

public:
   void Init(const string baseName, long magic)
   {
      m_magic    = magic;
      m_filename = baseName + "_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
      StringReplace(m_filename, ".", "-");
      m_handle = FileOpen(m_filename, FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
      if(m_handle == INVALID_HANDLE) { Print("LOGGER ERRO: ", m_filename); return; }
      FileWrite(m_handle, "Timestamp", "Tipo", "Mensagem");
      Print("Logger iniciado: ", m_filename);
   }

   void LogTrade(const string msg)
   {
      if(m_handle == INVALID_HANDLE) return;
      FileWrite(m_handle,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
         "TRADE", msg);
   }

   void LogDeal(ulong deal, double profit)
   {
      if(m_handle == INVALID_HANDLE) return;
      string sym   = HistoryDealGetString(deal, DEAL_SYMBOL);
      double price = HistoryDealGetDouble(deal, DEAL_PRICE);
      double vol   = HistoryDealGetDouble(deal, DEAL_VOLUME);
      string entry = (HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN) ? "ENTRADA" : "SAIDA";
      string msg   = StringFormat("%s | %s | Preco:%.2f | Vol:%.0f | Profit:R$%.2f",
                                  sym, entry, price, vol, profit);
      FileWrite(m_handle,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
         "DEAL", msg);
   }

   void LogDiaSeparator(const string data)
   {
      if(m_handle != INVALID_HANDLE) { FileClose(m_handle); m_handle = INVALID_HANDLE; }
      m_filename = "DTS_Log_" + data + ".csv";
      StringReplace(m_filename, ".", "-");
      m_handle = FileOpen(m_filename, FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
      if(m_handle != INVALID_HANDLE)
         FileWrite(m_handle, "Timestamp", "Tipo", "Mensagem");
   }

   void Flush()
   {
      if(m_handle != INVALID_HANDLE) { FileFlush(m_handle); FileClose(m_handle); m_handle = INVALID_HANDLE; }
   }
};
