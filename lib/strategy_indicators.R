# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Функции расчёта индикаторов
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
# ------------------------------------------------------------------------------
#' Вычисляет пересечения графиков рядов
#'
#' Вычисляются пересечения x1 'снизу-вверх' x2 (точки пробития вверх x2)
#' 
#' @param x1 xts1
#' @param x2 xts2
#'
#' @return x Ряд пересечений
#'
#' @export
CrossLine <- function(x1, x2, eq = FALSE) {
    if (eq == TRUE) {
        x <- diff(x1 >= x2)
    } else {
        x <- diff(x1 > x2)
    }
    x[1] <- 0
    x[x < 0] <- 0
    x <- sign(x)
    #
    return(x)
}
###
#' Надстройка нал CrossLine для удобства
#' @export
CrossLine.up <- function(x1, x2, eq = FALSE) {
    result <- CrossLine(x1, x2, eq)
    #
    return(result)
}
#
#' Надстройка нал CrossLine для удобства
#' @export
CrossLine.down <- function(x1, x2, eq = FALSE) {
    result <- CrossLine(x2, x1, eq)
    #
    return(result)
}
#
# ------------------------------------------------------------------------------
# Набор функций для расчёта индикаторов
#
#' Функция для расчёта SMA
#' 
#' @param x XTS
#' @param per Период SMA
#' @param digits Округление до знаков после точки
#'
#' @return x XTS ряд со значениями SMA
#'
#' @export
CalcIndicator.SMA <- function(x, per, digits = 0, ...) {
    #
    x <- 
        SMA(x = x, n = per) %>%
        round(., digits = digits)
    #
    return(x)
}
#
###
#' Функция для расчёта DCI
#' 
#' @param x XTS
#' @param per Период DCI
#' @param digits Округление до знаков после точки
#'
#' @return x XTS со значениями DCI ($high, $mid, $low)
#'
#' @export
CalcIndicator.DCI <- function(x, per, digits = 0, lag = TRUE) {
    #
    x <- 
        DonchianChannel(HL = x, n = per, include.lag = lag) %>%
        round(., digits = digits)
    #
    return(x)
}
#