# Загрузка библиотек
source('bots/test/linker.R')
#
### входные параметры
# temp.dir <- 'data/temp'
from.date <- '2016-02-01'
to.date <- '2016-02-28'
period <- '15min'
tickers <- c('SPFB.Si')
im.dir <- 'data/im'
ret_type <- 'ret'
sma_per <- 100
add_per <- 10
basket_weights <- c(1,0,0) # количество инструментов в портфеле
balance_start <- 1000000
k_mm <- 0.02  # mm на заход в сделку
slips <- c(0, 0, 0) # в пунктах
commissions <- c(10, 0, 0)  # в рублях
#
## подготовка исходных данных
# загрузка данных из .csv Финама
ohlc <- ReadOHLC.FinamCSV(filename = 'data/temp/si_data.csv')
# выделение нужного периода
ohlc <- 
  paste0(from.date,'::',to.date) %>%
  ohlc[.]
# переход к нужному периоду свечей
ohlc <- ExpandData.toPeriod(x = ohlc, per = '15min')
ohlc.list <- list(ohlc)
colnames(ohlc.list[[1]]) <- c('SPFB.SI.Open', 'SPFB.SI.High', 'SPFB.SI.Low','SPFB.SI.Close', 'SPFB.SI.Volume')
#
ohlc.list[[1]] <- 
  # удаление NA (по свечам)
  NormData_inXTS.na(data = ohlc.list[[1]], type = 'full') %>%
  # добавляем ГО и данные по USDRUB
  AddData_inXTS.futuresSpecs(data = ., from.date, to.date, dir = im.dir) %>%
  # вычисляем return'ы (в пунктах)
  CalcReturn_inXTS(data = ., price = 'Open', type = ret_type)
# суммарное ГО по корзине 
ohlc.list[[1]]$IM <- CalcSum_inXTS_byTargetCol.basket(data = ohlc.list[[1]], 
                                                           target = 'IM', basket_weights)
## расчёт суммарного return'a 
# перевод return'ов в валюту
ohlc.list[[1]]$SPFB.SI.cret <- ohlc.list[[1]]$SPFB.SI.ret 
ohlc.list[[1]]$cret <- ohlc.list[[1]]$SPFB.SI.cret 
#

### один прогон вычислений 
## отработка тестового робота
data_strategy.list <- TestStr.gear(ohlc = ohlc.list[[1]],
                                   sma_per, add_per, k_mm, balance_start, 
                                   basket_weights, slips, commissions)
## формирование таблицы сделок
# чистим от лишних записей
data_strategy.list[[2]] <- StateTable.clean(data_strategy.list[[2]])
# лист с данными по сделкам (по тикерам и за всю корзину)
basket <- TRUE
trade_table.list <- TradeTable.calc(data_strategy.list[[2]], basket = basket, convert = FALSE) #TRUE
# очистка мусора по target = 'temp'
CleanGarbage(target = 'temp', env = '.GlobalEnv')
gc()
## оценка perfomance-параметров
perfomanceTable <- 
  PerfomanceTable(data_strategy.list, 
                  trade_table = trade_table.list,
                  balance = balance_start, 
                  ret_type = ret_type) %>%
  # добавление использованных параметров
  cbind.data.frame(., sma_per = sma_per, add_per = add_per, k_mm = k_mm)
## запись в файл 
if (firstTime == TRUE) {
  write.table(perfomanceTable, file = perfomanceDB.filename, sep = ',', col.names = TRUE )  
  firstTime <- FALSE
} else {
  write.table(perfomanceTable, file = perfomanceDB.filename, sep = ',', col.names = FALSE, append = TRUE )  
}
#