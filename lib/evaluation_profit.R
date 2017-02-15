# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Функции расчета метрик доходности:
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
###
#' Расчёт итоговой таблицы с данными по доходностям 
#'
#' Функция вычисляет параметры по доходностям (дней и сделок) и формирует итоговый DF 
#' 
#' @param data Полные данные (после    отработки стратегии)
#' @param balance Стартовый баланс
#'
#' @return profitTable DF с данными по profit'у
#'
#' @export
ProfitTable <- function(data, trades_table, balance_start, ...) {
    ### расчёт итоговой доходности 
    # здесь для анализа используется equty, чтобы лишний раз не считать разницу
    full_return <- 
        xts::last(data$equity) %>%
        as.numeric(.)
    full_return_percent <- full_return * 100 / balance_start        
    ## доходность в год
    full_return_annual <- 
        index(data) %>%
        ndays(.) %>%
        {
            full_return * 250 / .
        }        
    ## доходность в месяц
    full_return_monthly <-
        index(data) %>%
        ndays(.) %>%
        {
            full_return * 20 / .
        }
 
    ### расчёт метрик по дням
    profit_table_byDays <- ProfitTable.byDays(data)
    ### расчёт метрик по сделкам для корзины
    profit_table_byTrades <-    
        ProfitList_byTrades(data = trades_table[[1]]) %>%
        {
            .[[1]]
        }
    ### формирование итогового DF
    profit_table <- 
        data.frame(
            Profit = full_return,
            ProfitPercent = full_return_percent,
            ProfitAnnual = full_return_annual,
            ProfitMonthly = full_return_monthly,
            row.names = NULL
        ) %>%
        {
            x <- .
            args <- list(...) 
            args_names <- names(args)
            if (('nbar' %in% args_names) && ('nbar.trade' %in% args_names) == TRUE ) {
                full_return_bar <- full_return / args$nbar
                full_return_nbar_trade <- full_return / args$nbar.trade
                x <- cbind(x, ProfitBars = full_return_bar, ProfitBarsIn = full_return_nbar_trade)
            }
            return(x)
        } %>%
        cbind(., profit_table_byDays, profit_table_byTrades)
    #
    return(profit_table)
}
#