# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# описания стратегий и вспомагательных функций
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
# ------------------------------------------------------------------------------
#' Переход к состояниям (фильтрация сигналов)
#'
#' @param x Ряд сигналов стратегии
#'
#' @return x$y ряд сделок (отфильтрованный ряд сигналов)
#'
#' @export
Convert.signal_to_states <- function(x) {
    x$a <-
        na.locf(x) %>%
        ifelse(is.na(x$a) | is.nan(x$a) | is.infinite(x$a), 0, x$a)
    ind <- which(x$a != stats::lag(x$a))
    x$y <- rep(NA, length(x$a))
    x$y[ind] = x$a[ind]
    x$y[1] <- x$a[1]
    #
    return(x$y)
}
# ------------------------------------------------------------------------------
#' Функция для перехода к состояниям (фильтрация сигналов)
#'
#' @param x Ряд позиций (data$pos)
#'
#' @return state Ряд состояний
#'
#' @export
CalcStates.inData <- function(x) {
    #
    x <-
        na.locf(x) %>%
        { 
            ifelse(is.na(.) | is.nan(.) | is.infinite(.), 0, .)
        } %>%
        xts(., order.by = index(x))
    ind <- which(x != stats::lag(x))
    state <- rep(NA, length(x))
    state[ind] <- x[ind]
    state[1] <- x[1]
    #
    return(state)
}
###
#' Генерирует таблицу сделок
#'
#' @param x Полные данные отработки стратегии
#'
#' @return result Данные с рядом состояний
#'
#' @export
CalcStates.table <- function(x) {
    #
    result <-
        x$pos %>%
        CalcStates.inData(.) %>%
        {
            merge(x, state = .)
        } %>%
        na.omit(.)
    #
    return(result)
}
###
#' Функция вычисляет return'ы по всему портфелю внутри XTS
#'
#' @param data XTS
#' @param type Тип return'a (ret/sret/lret)
#'
#' @return data XTS + return'ы по каждому инструменту
#'
#' @export
CalcReturn_inXTS <- function(data, price = 'Close', type = 'sret') {
    require(quantmod)
    # ----------
    data.names <-
       names(data)[grep('Close', names(data))] %>%
       sub('.Close', '', .)
    for (i in 1:length(data.names)) {
        temp.text <- paste0(
            'data$',data.names[i],'.',type,' <- CalcReturn(',
                'data$',data.names[i],'.',price,', type = \"',type,'\"',
            ')'
        )
        eval(parse(text = temp.text))
    }
    #
    return(data)
}
#
###
#' Функция расчета equity
#'
#' @param data Данные с доходностями и позициями
#'
#' @return data Данные + объем(w), относительной прибылью(margin), equity
#'
#' @export
CalcEquity <- function(data, s0 = 0, abs = FALSE, SR = FALSE, LR = FALSE, reinvest = TRUE, state = FALSE) {
    require(quantmod)
    # ----------
    # расчет
    if (state == FALSE) {
        data$state <- data$pos
    }
    if (abs == TRUE) {
        if (reinvest == TRUE) {
            data$w <- data$state[[1]] * s0/data$Open[[1]]
            data$w <- trunc(data$w)
            data$equity <- s0
            data$margin <- 0
            for (i in 2:nrow(data)) {
                data$margin[i] <- data$w[[i-1]] * ( data$Open[[i]] - data$Open[[i-1]] )
                data$equity[i] <- (data$equity[[i-1]] + data$margin[[i]])
                data$w[i] <- data$state[[i]] * data$equity[[i]] / data$Open[[i]]
                data$w[i] <- trunc(data$w[i])
            }
        } else {
            data$w <- 1
            data$margin <- stats::lag(data$state) * ( data$Open-stats::lag(data$Open) )
            data$margin[1] <- 0
            data$equity <- cumsum(data$margin)
        }
    }
    if (SR == TRUE) {
        if (reinvest == TRUE) {
          data$SR <- stats::lag(data$state) * data$SR
          data$SR[1] <- 0
        data$margin <- cumprod(data$SR + 1)
        data$margin[1] <- 0
        data$equity <- s0*data$margin
        } else {
            data$SR <- stats::lag(data$state) * data$SR
            data$SR[1] <- 0
            data$margin <- cumprod(data$SR + 1) - 1
            data$equity <- data$Open[[1]] * as.numeric(data$margin)
        }
    }
    if (LR == TRUE) {
        #if (reinvest==TRUE) {
            #
        #} else {
            data$LR <- stats::lag(data$state) * data$LR
            data$LR[1] <- 0
            data$margin <- cumsum(data$LR)
            data$equity <- data$Open[[1]] * (exp(as.numeric(xts::last(data$margin))) - 1)
        #}
    }
    #
    return(data)
}
#
# ------------------------------------------------------------------------------
#' Функция расчета профита
#'
#' Устаревшая функция
#'
#' @param data Данные с equity (в пунктах)
#' @param s0 Начальный баланс
#' @param pip Размер пункта
#'
#' @return profit Итоговый профит
#'
#' @export
CalcProfit <- function(data, s0 = 0, pip, reinvest = TRUE) {
    require(quantmod)
    # расчет итогового профита
    if (reinvest == TRUE) {
        profit <- as.numeric(xts::last(data$equity / pip) - s0)
    } else {
        profit <- as.numeric(xts::last(data$equity / pip))
    }
    #
    return(profit)
}
#
# ------------------------------------------------------------------------------
# Функции нормирования исходных данных
#
#' Функция для расчёта стоимости тиков внутри основного листа данных
#'
#' @param data XTS данные котировок (основной лист данных)
#' @param names Список тикеров для конвертирования
#' @param norm.data Нормировочные данные
#' @param outnames Название столбца для результатов
#' @param convert.to
#' @param tick.val Тиков в шаге цены
#' @param tick.price Цена тика
#'
#' @return data Основной XTS (нужные данные конвертированы к нужной валюте)
#'
#' @export
NormData_inXTS.price <- function(data, names, norm.data, outnames, convert.to, tick.val, tick.price) {
    x <- norm.data
    for (i in 1:length(names)) {
        temp.text <- paste0(
            'data$',outnames[i],' <- NormData.price(',
                'data = data$',names[i],',',
                'norm.data = x, convert.to = \"',convert.to,'\",',
                'tick.val = ',tick.val[i],',',
                'tick.price = ', tick.price[i],')'
        )
        eval(parse(text = temp.text))
    }
    #
    return(data)
}
###
#' Функция для расчёта стоимости тиков
#'
#' @param data XTS, содержащий нужные данные
#' @param norm.data Нормировочные данные
#' @param convert.to Валюта конвертирования (USD/RUB)
#' @param tick.val Тиков в шаге цены
#' @param tick.price Цена тика
#'
#' @return data XTS ряд
#'
#' @export
NormData.price <- function(data, norm.data, convert.to, tick.val, tick.price) {
    if (convert.to == 'RUB') {
        data <- (data * tick.price / tick.val) * norm.data
    }
    if (convert.to == 'USD') {
        data <- (data * tick.price / tick.val) / norm.data
    }
    #
    return(data)
}
# ------------------------------------------------------------------------------
#' Расчёт суммарного параметра (согласно весам инструмента в портфеле)
#'
#' @param data xts с данными корзины
#' @param basket_weights Веса инструментов внутри корзины
#' @param target Ключ поиска нужных столбцов
#'
#' @return data Суммированные данные (столбец)
#'
#' @export
CalcSum_inXTS_byTargetCol.basket <- function(data, basket_weights, target) {
  #require()
  #
    temp.text <-
        names(data)[grep(target, names(data))] %>%
        paste0('data$', .) %>%
        paste(., basket_weights, sep = ' * ', collapse = ' + ') %>%
        paste0('data <- ', .)
    eval(parse(text = temp.text))
    #
    return(data)
}
#
# ------------------------------------------------------------------------------
#' Функция расщепления переворотных сделок
#'
#' @param data Полные данные отработки робота
#'
#' @return data Данные с расщеплёнными позициями-переворотами
#'
#' @export
SplitSwitchPosition <- function(data) {
    ## Точки смены позиций
    data$action <- diff(data$pos)
    data$action[1] <- data$pos[1]
    # индекс строки-переворота
    temp.ind <- index(data[data$action == 2 | data$action == -2])
    if (length(temp.ind) == 0) {
        cat('TestStrategy INFO: No Switch Position there', '\n')
        rm(temp.ind)
    } else {
        cat('TestStrategy INFO:  Split SwitchPosition...', '\n')
        # temp копия нужных строк (строки начала новой сделки)
        temp <-
            data[temp.ind] %>%
            {
                x <- .
                x$pos <- sign(x$action)
                # x$state <- sign(x$action)
                x$action <- abs(sign(x$action))
                return(x)
            }
        # cтроки предыдущей сделки
        data$pos[temp.ind] <- 0
        # data$state[temp.ind] <- sign(data$action[temp.ind])
        data$action[temp.ind] <- abs(sign(data$action[temp.ind]))
        data$pos.num[temp.ind] <- data$pos.num[temp.ind] - 1
        # правильное заполнение поля $pos.bars
        temp.ind.num <- data[temp.ind, which.i = TRUE]
        data$pos.bars[temp.ind] <- data$pos.bars[temp.ind.num - 1]
        data <- rbind(data, temp)
        rm(temp.ind)
    }
    #
    return(data)
}
#
# ------------------------------------------------------------------------------
#' Функция подсчёта числа баров в позициях
#'
#' @param x Ряд позиций
#'
#' @return result Ряд с числом баров в позициях
#'
#' @export
CalcPosition.bars <- function(x) {
    result <-
        # вектор, содержащий номера позиций
        unique(x) %>%
        # нумерация тиков внутри состояний сигналов
        {
            if (length(.) == 1) {
              .
            } else {
                sapply(.,
                    function(var) {
                        temp <- abs(sign(which(x == var)))
                        temp[1] <- 0
                        xts(x = cumsum(temp), order.by = index(x[x == var]))
                    }) %>%
                MergeData_inList.byRow(.)
            }
        }
    #
    return(result)
}
#
###
#' Функция подсчёта позиций
#'
#' @param x Ряд позиций
#'
#' @return result Ряд номеров позиций
#'
#' @export
CalcPosition.num <- function(x) {
    action <- diff(x)
    action[1] <- x[1]
    result <-
        abs(sign(action)) %>%
        # защита от нумерации позиций 'вне рынка'
        {
        abs(sign(x)) * .
        } %>%
        cumsum(.) %>%
        # защита от нумераций пачек нулевых позиций
        {
            temp <- action
            temp[1] <- 0
            temp <- abs(sign(temp))
            x <- . * sign(temp + abs(x))
            return(x)
        }
    #
    return(result)
}
#
###
#' Функция очистки сигналов от повторяющихся
#'
#' @param x Ряд сигналов
#'
#' @return result Очищенный ряд сигналов
#'
#' @export
CleanSignal.duplicate <- function(x) {
    result <-
        diff(x) %>%
        {
            .[1] <- x[1]
            return(.)
        } %>%
        sign(.) %>%
        abs(.) %>%
        {
            x * .
        }
    #
    return(result)
}
#
###
#' Функция расчёта позиций относительно ордеров
#'
#' @param bto Данные buy-to-open (open long positions)
#' @param stc Данные sell-to-close (close long positions)
#' @param sto Данные sell-to-open (open short positions)
#' @param btc Данные buy-to-close (close short positions)
#'
#' @return result DF c $open и $close сделок
#'
#' @export
CalcPosition_byOrders <- function(bto, stc, sto, btc) {
    #FUN <- match.fun(FUN)
    temp.env <- new.env()
    rows <- length(bto)
    ind <- 1:rows
    result <- data.frame(open = integer(rows), close = integer(rows))
    time.ind <- index(bto)
    bto <- coredata(bto) %>% as.integer(.)
    stc <- coredata(stc) %>% as.integer(.)
    sto <- coredata(sto) %>% as.integer(.)
    btc <- coredata(btc) %>% as.integer(.)
    assign('cache.state', 0, envir = temp.env)
    sapply(ind,
        function(x) {
            cache.state <- get('cache.state', envir = temp.env)
            result <- get('result', envir = temp.env)
            #data[x, ] <- FUN(data, x, ...)
            result$open[x] <- ifelse(cache.state == 0 | is.na(cache.state),
                ifelse(bto[x] != 0, 
                    bto[x], 
                    sto[x]),
                ifelse(stc[x] == cache.state,
                    0,
                    ifelse(btc[x] == cache.state,
                        0,
                        cache.state)))
            result$close[x] <- ifelse(cache.state != 0 | !is.na(cache.state),
                ifelse(btc[x] == cache.state,
                    btc[x],
                    ifelse(stc[x] == cache.state,
                        stc[x],
                        0)),
                0)
            cache.state <- result$open[x]
            #
            assign('cache.state', cache.state, envir = temp.env)
            assign('result', result, envir = temp.env)
        }
    )
    result <- get('result', envir = temp.env)
    rm(temp.env)
    result <- xts(result, order.by = time.ind)
    #
    return(result)
}
#
###
#' Функция очистки сигналов на датах экспирации
#'
#' @param signals Данные ордеров (bto/stc/sto/btc)
#' @param exp.vector Вектор с датами экспирации
#' @param pos Расчёт по состояниям или ордерам
#'
#' @return result.list Лист с очищенными рядами сигналов
#'
#' @export
CleanSignal.expiration <- function(signals, exp.vector, pos = FALSE) {
    require(lubridate)

    if (pos == FALSE) {
        # выделение данных ордеров
        col.names <- names(signals)
        bto_col <- grep('bto', col.names)
        stc_col <- grep('stc', col.names)
        sto_col <- grep('sto', col.names)
        btc_col <- grep('btc', col.names)
    }

    temp.ind <-
        index(signals) %>%
        strptime(., '%Y-%m-%d') %>%
        unique(.) %>%
        as.POSIXct(., origin = '1970-01-01', tz='MSK')
    temp.ind <-
        {
            which(temp.ind %in% exp.vector)
        } %>%
        temp.ind[.] %>%
        as.character(.)

    if (length(temp.ind) != 0) {
        if (pos == FALSE) {
            # удаление входов в дни экспирации
            signals[temp.ind, bto_col] <- 0
            signals[temp.ind, sto_col] <- 0
        }
        # принудительное закрытие сделок в 16:00 дня экспирации
        temp.ind <-
            as.character(temp.ind) %>%
            paste(., '16:00:00', sep = ' ')
        if (pos == FALSE) {
            signals[temp.ind, stc_col] <- 1
            signals[temp.ind, btc_col] <- -1
        } else {
            signals[temp.ind] <- 0
        }
    }
    rm(temp.ind)
    #
    return(signals)
}
#
###
#' Функция фильтрации канальных индикаторах на утренних gap'ах
#'
#' @param signals Данные ордеров (bto/stc/sto/btc)
#'
#' @return result.list Лист с очищенными рядами сигналов
#'
#' @export
CleanSignal.gap <- function(signals) {
    # расчёт enpoint'ов
    ends <- CalcEndpoints(x = signals, on = 'days', k = 1, findFirst = TRUE)
    signals$gap <- 0
    # свечи gap'ов
    signals$gap[ends] <- 1

    # выделение данных ордеров
    col.names <- names(signals)
    bto_col <- grep('bto', col.names)
    stc_col <- grep('stc', col.names)
    sto_col <- grep('sto', col.names)
    btc_col <- grep('btc', col.names)

    ## на gap'ах:
    # заход в позиции запрещён
    signals[ends, bto_col] <- 0
    signals[ends, sto_col] <- 0
    #data <- na.omit(data)

    # # выходы на следующей свече по Open
    # temp.ind <- which(signals$gap == 1 & signals[, stc_col] != 0)
    # if (length(temp.ind) != 0) {
    #     signals[temp.ind + 1, stc_col] <- ifelse(signals[temp.ind, stc_col] != 0,
    #         signals[temp.ind, stc_col],
    #         0)
    #     #signals[temp.ind, stc_col] <- 0
    # }
    # rm(temp.ind)
    # temp.ind <- which(signals$gap == 1 & signals[, btc_col] != 0)
    # if (length(temp.ind) != 0) {
    #     signals[temp.ind + 1, btc_col] <- ifelse(signals[temp.ind, btc_col] != 0,
    #         signals[temp.ind, btc_col],
    #         0)
    #     #signals[temp.ind, btc_col] <- 0
    # }
    # rm(temp.ind)
    signals[ends, stc_col] <- 0
    signals[ends, btc_col] <- 0

    gap <- signals$gap
    signals$gap <- NULL
    rm(ends)
    result.list <- list(signals, gap)
    #
    return(result.list)
}
# ------------------------------------------------------------------------------
#' Функция вычисления цены инструмента с учётом проскальзывания (на action-точках)
#'
#' @param price Данные цен на сделках
#' @param action Данные action
#' @param data_source Данные с котировками
#' @param slips Слипы
#'
#' @return price XTS с ценами
#'
#' @export
CalcPrice.slips <- function(price, action, data_source, slips) {
    price <- price + slips * sign(action)
    price.ind <- index(price)
    low.ind <-
        {
            which(price < Lo(data_source[price.ind]))
        } %>%
        price.ind[.]
    high.ind <-
        {
            which(price > Hi(data_source[price.ind]))
        } %>% 
        price.ind[.]
    price[low.ind] <- Lo(data_source[low.ind])
    price[high.ind] <- Hi(data_source[high.ind])
    #
    return(price)
}
# ------------------------------------------------------------------------------
#' Очистка таблицы состояний от пустых сделок
#'
#' Чистит таблицу сделок от строк, у которых df$pos != 0 & df$n == 0 & df$diff.n ==0
#'
#' @param data Входной xts ряд состояний
#'
#' @return data Очищенный xts ряд состояний
#'
#' @export
StatesTable.clean <- function(data) {
    data %<>%
        # условие для фильтрации "пустых сделок" (т.е. фактически ранее уже закрытых позиций)
        {
            df <- .
            if ((df$n == 0 && df$diff.n ==0) != FALSE) {
                df <- df[-which(df$n == 0 & df$diff.n ==0)]
            }
            return(df)
        }
    return(data)
}
#
# ------------------------------------------------------------------------------
#' Функция для расчёта позиций
#'
#' @param data_source XTS с исходными котировками
#' @param exp.vector Вектор с датами экспирации
#' @param gap_filter Фильтрация на gap'ах
#' @param FUN_AddIndicators Функция расчета индикаторов
#' @param FUN_AddSignals Функция расчета торговых сигналов
#' @param FUN_CleanOrders Функция очистки ордеров
#' @param FUN_CalcPosition_byOrders Функция расчета позиций
#' @param ... Исходные параметры индикаторов
#'
#' @return data 
#'
#' @export
AddPositions <- function(data_source, exp.vector, gap_filter = TRUE,
                         FUN_AddIndicators, FUN_AddSignals,
                         FUN_CleanOrders, FUN_CalcPosition_byOrders,
                         ...) {
    #
    FUN_AddIndicators <- match.fun(FUN_AddIndicators)
    FUN_AddSignals <- match.fun(FUN_AddSignals)
    FUN_CleanOrders <- match.fun(FUN_CleanOrders)
    FUN_CalcPosition_byOrders <- match.fun(FUN_CalcPosition_byOrders)
    dots <- list(...)

    ### Расчёт индикаторов и позиций
    ## 1.1 Добавляем индикаторы (fastSMA & slowSMA, DCI) и позиции
    data <- xts()
    #
    data <- FUN_AddIndicators(ohlc_source = data_source, ...)
    #
    ## Расчёт сигналов и позиций
    #cat('TurtlesStrategy INFO:  Calculate $sig and $pos...', '\n')
    data <- FUN_AddSignals(data = data, ohlc_source = data_source)
    # выделение сигналов на ордера в отдельный XTS
    order.xts <- xts()
    order.xts$bto <- Subset_byTarget.col(data = data, target = 'bto')
    order.xts$sto <- Subset_byTarget.col(data = data, target = 'sto')
    order.xts$stc <- Subset_byTarget.col(data = data, target = 'stc')
    order.xts$btc <- Subset_byTarget.col(data = data, target = 'btc')

    ### фильтрация индикаторов на утренних gap'ах
    if (gap_filter == TRUE) {
        order.list <- CleanSignal.gap(signals = order.xts)
        data$gap <- order.list[[2]]
    } else {
        order.list <- list(order.xts)
    }
    rm(order.xts)

    ### фильтрация сделок на склейках фьючерсов
    if (!is.null(exp.vector)) {
        order.list[[1]] <- CleanSignal.expiration(
            signals = order.list[[1]],
            exp.vector = exp.vector)
    }
    #
    #order.list[[1]] <- na.omit(order.list[[1]])
    data <- na.omit(data)

    ### Фильтрация ордеров в сделках
    temp.list <- FUN_CleanOrders(orders = order.list[[1]], data = data)
    order.list[[1]] <- temp.list[[1]]
    data <- temp.list[[2]]
    rm(temp.list)

    ### Добавление столбцов сделок в основную таблицу
    data <- FUN_CalcPosition_byOrders(orders = order.list[[1]], data = data)
    rm(order.list)
    #
    return (data)
}
# ------------------------------------------------------------------------------
# Функции для расчета данных по сделкам
#
#' Функция расчёта сделок
#'
#' @param data Данные states
#' @param Calc_one_trade.FUN Функция обсчёта одной сделки
#' @param commiss Коммиссия
#' @param data_source Исходные данные котировок
#' @param balance_start Стартовый баланс
#' @param ... Параметры, специфичные для стратегии
#'
#' @return result DF с данными по сделкам
#'
#' @export
CalcTrades_inStates <- function(data, Calc_one_trade.FUN,
                                commiss, data_source, balance_start,
                                target_col = c('n', 'diff.n', 'balance', 'im', 'im.balance', 'commiss',
                                              'margin', 'perfReturn', 'equity'),
                                ...) {
    FUN <- match.fun(Calc_one_trade.FUN)
    temp.env <- new.env()
    ind <- 1:nrow(data)
    temp.cache <-
        data[, target_col] %>%
        as.data.frame(., row.names=NULL)
    assign('cache', temp.cache, envir = temp.env)
    rm(temp.cache)
    sapply(ind,
        function(x) {
            cache <- get('cache', envir = temp.env)
            #data[x, ] <- FUN(data, x, ...)
            temp.ind <- index(data[x, ])
            cache <- FUN(cache = cache, 
                row_ind = x,
                pos = data$pos[x], pos_bars = data$pos.bars[x],
                IM = data_source$IM[temp.ind], cret = data$cret[x],
                balance_start = balance_start, commiss = commiss,
                ...)
            #
            assign('cache', cache, envir = temp.env)
        }
    )
    result <- get('cache', envir = temp.env)
    rm(temp.env)
    #
    return(result)
}
#
#' Функция расчёта данных одной сделки
#'
#' @param cahce Данные кэша
#' @param row_ind Номер анализируемой строки
#' @param pos Позиция
#' @param pos_bars Число баров в позиции
#' @param MM.FUN Функция MM
#' @param IM ГО
#' @param cret Return (в деньгах)
#' @param balance_start Стартовый баланс
#' @param commiss Коммиссия
#' @param ... Параметры, специфичные MM стратегии
#'
#' @return data DF с данными по сделкам
#'
#' @export
CalcTrades_inStates_one_trade <- function(cache, row_ind, pos, pos_bars,
                                          MM.FUN,  IM, cret, balance_start, commiss,
                                          external_balance = NULL,
                                          ...) {
    MM.FUN <- match.fun(MM.FUN)
    #
    cache$n[row_ind] <- ifelse(coredata(pos) == 0,
        0,
        ifelse(coredata(pos_bars) == 0,
            MM.FUN(
                balance = ifelse(!is.null(external_balance),
                    external_balance,
                    cache$balance[row_ind - 1]), #* cache$weight[row_ind - 1]),
                IM = IM,
                ...
            ),
            cache$n[row_ind - 1])
    )
    cache$diff.n[row_ind] <- ifelse(row_ind != 1,
        cache$n[row_ind] - cache$n[row_ind - 1],
        0)
    cache$commiss[row_ind] <- commiss * abs(cache$diff.n[row_ind])
    cache$margin[row_ind] <- ifelse(row_ind != 1,
        coredata(cret) * cache$n[row_ind - 1],
        0)
    cache$perfReturn[row_ind] <- cache$margin[row_ind] - cache$commiss[row_ind]
    cache$equity[row_ind] <- ifelse(row_ind != 1,
        sum(cache$perfReturn[row_ind], cache$equity[row_ind - 1]),
        0)
    cache$im.balance[row_ind] <- IM * cache$n[row_ind]
    if (!is.null(external_balance)) {
        cache$balance[row_ind] <- NA
    } else {
        cache$balance[row_ind] <- ifelse(row_ind != 1,
            balance_start + cache$equity[row_ind] - cache$im.balance[row_ind],
            cache$balance[row_ind])
    }
    #
    return(cache)
}
# ------------------------------------------------------------------------------
### Функции-handler'ы сделок
#
#' Функция-обработчик сделок
#'
#' @param data Посвечные данные отработки робота
#' @param states Данные состояний
#' @param ohlc_source Котировки
#' @param commiss Коммиссия
#' @param balance_start Стартовый баланс
#' @param FUN.CalcTrades Функция расчета сделок
#' @param ... Параметры, специфичные MM стратегии
#'
#' @return Лист с данными стратегии (data + states)
#'
#' @export
Trades_handler <- function(data, states, ohlc_source,
                           commiss, balance_start,
                           FUN.CalcTrades,
                           ...) {
    #
    FUN.CalcTrades <- match.fun(FUN.CalcTrades)
    # 2.1.4 Начальные параметры для расчёта сделок
    # начальный баланс
    states$balance <- NA
    states$balance[1] <- balance_start
    # начальное число синтетических контрактов корзины
    states$n <- NA
    #states$n <- 0
    # прочее
    states$diff.n <- NA
    states$diff.n[1] <- 0
    states$margin <- NA
    states$commiss <- NA
    states$equity <- NA
    states$im.balance <- NA
    states$im.balance[1] <- 0
    # т.к. обработчик не пакетный, вес бота всегда = 1
    #states$weight <- 1
    ## 2.2 Расчёт самих сделок
    temp.df <- FUN.CalcTrades(
        data = states, commiss = commiss,
        data_source = ohlc_source,
        balance_start = balance_start, #* states$weight[1],
        ...
    )
    # Изменение контрактов на такте
    states$n <- temp.df$n
    states$diff.n <- temp.df$diff.n
    # Расчёт баланса, заблокированного на ГО
    states$im.balance <- temp.df$im.balance
    # Расчёт комиссии на такте
    states$commiss <- temp.df$commiss
    # Расчёт вариационки
    states$margin <- temp.df$margin
    # расчёт equity по корзине в states
    states$perfReturn <- temp.df$perfReturn
    states$equity <- temp.df$equity
    # Расчёт баланса
    states$balance <- temp.df$balance
    #
    rm(temp.df)
    #
    ## Перенос данных из state в full таблицу
    # перенос данных по количеству контрактов корзины
    data$n <-
        merge(data, states$n) %>%
        {
            data <- .
            data$n <- na.locf(data$n)
            return(data$n)
        }
    # перенос данных по комиссии корзины
    data$commiss <-
        merge(data, states$commiss) %>%
        {
            data <- .
            data$commiss[is.na(data$commiss)] <- 0
            return(data$commiss)
        }
    # перенос данных по суммарному ГО
    data$im.balance <-
        merge(data, states$im.balance) %>%
        {
            data <- .
            data$im.balance <- na.locf(data$im.balance)
            return(data$im.balance)
        }
    ## Расчёт показателей в full данных
    # расчёт вариационки в data
    data$margin <- stats::lag(data$n) * data$cret
    data$margin[1] <- 0
    # расчёт equity по корзине в data
    data$perfReturn <- data$margin - data$commiss
    data$equity <- cumsum(data$perfReturn)
    # расчёт баланса
    data$balance <- balance_start + data$equity - data$im.balance
    data$balance[1] <- balance_start
    #
    return(list(data = data, states = states))
}