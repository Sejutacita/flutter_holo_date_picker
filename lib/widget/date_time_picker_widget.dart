import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../date_picker_constants.dart';
import '../date_picker_theme.dart';
import '../date_time_formatter.dart';
import '../i18n/date_picker_i18n.dart';

/// Solar months of 31 days.
const List<int> _solarMonthsOf31Days = const <int>[1, 3, 5, 7, 8, 10, 12];

/// DatePicker widget.
class DateTimePickerWidget extends StatefulWidget {
  DateTimePickerWidget({
    Key? key,
    this.firstDate,
    this.lastDate,
    this.initialDate,
    this.dateFormat: DATETIME_PICKER_DATE_FORMAT,
    this.locale: DATETIME_PICKER_LOCALE_DEFAULT,
    this.pickerTheme: DateTimePickerTheme.Default,
    this.onCancel,
    this.onChange,
    this.onConfirm,
    this.looping: false,
    this.indicatorBackgroundWidget,
    this.isLimitHourAndMinuteSelectionBasedOnFirstDate = false,
  }) : super(key: key) {
    final minTime = firstDate ?? DateTime.parse(DATE_PICKER_MIN_DATETIME);
    final maxTime = lastDate ?? DateTime.parse(DATE_PICKER_MAX_DATETIME);
    assert(minTime.compareTo(maxTime) < 0, '');
  }

  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialDate;
  final String? dateFormat;
  final DateTimePickerLocale? locale;
  final DateTimePickerTheme? pickerTheme;
  final DateVoidCallback? onCancel;
  final DateValueCallback? onChange;
  final DateValueCallback? onConfirm;
  final bool looping;
  final Widget? indicatorBackgroundWidget;

  /// [isLimitHourAndMinuteSelectionBasedOnFirstDate] will limit the hour and
  /// minute selection based on the first date selected. This is useful when
  /// you want to restrict the available hours and minutes based on the first
  /// date.
  final bool isLimitHourAndMinuteSelectionBasedOnFirstDate;

  @override
  State<StatefulWidget> createState() => _DateTimePickerWidgetState(
        this.firstDate,
        this.lastDate,
        this.initialDate,
        this.isLimitHourAndMinuteSelectionBasedOnFirstDate,
      );
}

class _DateTimePickerWidgetState extends State<DateTimePickerWidget> {
  late DateTime _minDateTime;
  late DateTime _maxDateTime;
  int? _currYear;
  int? _currMonth;
  int? _currDay;
  int? _currHour;
  int? _currMinute;
  List<int>? _yearRange;
  List<int>? _monthRange;
  List<int>? _dayRange;
  List<int>? _hourRange;
  List<int>? _minuteRange;
  FixedExtentScrollController? _yearScrollCtrl;
  FixedExtentScrollController? _monthScrollCtrl;
  FixedExtentScrollController? _dayScrollCtrl;
  FixedExtentScrollController? _hourScrollCtrl;
  FixedExtentScrollController? _minuteScrollCtrl;

  late Map<String, FixedExtentScrollController?> _scrollCtrlMap;
  late Map<String, List<int>?> _valueRangeMap;

  bool _isChangeDateRange = false;
  // whene change year the returned month is incorrect with the shown one
  // So locks make sure that month doesn't change from cupertino widget
  // we will handle it manually
  bool _monthLock = false;
  bool _minuteLock = false;

  bool isLimitHourAndMinuteSelectionBasedOnFirstDate = false;
  _DateTimePickerWidgetState(
    DateTime? minDateTime,
    DateTime? maxDateTime,
    DateTime? initialDateTime,
    bool isLimitHourAndMinuteSelectionBasedOnFirstDate,
  ) {
    this.isLimitHourAndMinuteSelectionBasedOnFirstDate =
        isLimitHourAndMinuteSelectionBasedOnFirstDate;
    // handle current selected year、month、day
    final initDateTime = initialDateTime ?? DateTime.now();
    this._currYear = initDateTime.year;
    this._currMonth = initDateTime.month;
    this._currDay = initDateTime.day;
    this._currHour = initDateTime.hour;
    this._currMinute = initDateTime.minute;

    // handle DateTime range
    this._minDateTime = minDateTime ?? DateTime.parse(DATE_PICKER_MIN_DATETIME);
    this._maxDateTime = maxDateTime ?? DateTime.parse(DATE_PICKER_MAX_DATETIME);

    // limit the range of year
    this._yearRange = _calcYearRange();
    this._currYear = min(max(_minDateTime.year, _currYear!), _maxDateTime.year);

    // limit the range of month
    this._monthRange = _calcMonthRange();
    this._currMonth = _calcCurrentMonth();

    // limit the range of day
    this._dayRange = _calcDayRange();
    this._currDay = min(max(_dayRange!.first, _currDay!), _dayRange!.last);

    // limit the range of hour
    this._hourRange = isLimitHourAndMinuteSelectionBasedOnFirstDate
        ? [_minDateTime.hour, 23]
        : [0, 23];

    // limit the range of minute
    this._minuteRange = _calcMinutesRange();

    this._currHour = min(max(_minDateTime.hour, _currHour!), 23);
    this._currMinute = _calcCurrentMinute();

    // create scroll controller
    _yearScrollCtrl = FixedExtentScrollController(
      initialItem: _currYear! - _yearRange!.first,
    );
    _monthScrollCtrl = FixedExtentScrollController(
      initialItem: _currMonth! - _monthRange!.first,
    );
    _dayScrollCtrl = FixedExtentScrollController(
      initialItem: _currDay! - _dayRange!.first,
    );
    _hourScrollCtrl = FixedExtentScrollController(
      initialItem: _currHour! - _hourRange!.first,
    );
    _minuteScrollCtrl = FixedExtentScrollController(
      initialItem: _currMinute! - _minuteRange!.first,
    );

    _scrollCtrlMap = {
      'y': _yearScrollCtrl,
      'M': _monthScrollCtrl,
      'd': _dayScrollCtrl,
      'H': _hourScrollCtrl,
      'm': _minuteScrollCtrl
    };
    _valueRangeMap = {
      'y': _yearRange,
      'M': _monthRange,
      'd': _dayRange,
      'H': _hourRange,
      'm': _minuteRange
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.indicatorBackgroundWidget ??
            Container(
              width: double.maxFinite,
              height: 31,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0XFFF4F4F4),
              ),
            ),
        GestureDetector(
          child: Material(
            color: Colors.transparent,
            child: _renderPickerView(context),
          ),
        ),
      ],
    );
  }

  /// render date picker widgets
  Widget _renderPickerView(BuildContext context) {
    final datePickerWidget = _renderDatePickerWidget();

    return datePickerWidget;
  }

  /// notify selected date changed
  void _onSelectedChange() {
    if (widget.onChange != null) {
      final dateTime = DateTime(
          _currYear!, _currMonth!, _currDay!, _currHour!, _currMinute!);
      widget.onChange!(dateTime, _calcSelectIndexList());
    }
  }

  /// find scroll controller by specified format
  FixedExtentScrollController? _findScrollCtrl(String format) {
    FixedExtentScrollController? scrollCtrl;
    _scrollCtrlMap.forEach((key, value) {
      if (format.contains(key)) {
        scrollCtrl = value;
      }
    });
    return scrollCtrl;
  }

  /// find item value range by specified format
  List<int>? _findPickerItemRange(String format) {
    List<int>? valueRange;
    _valueRangeMap.forEach((key, value) {
      if (format.contains(key)) {
        valueRange = value;
      }
    });
    return valueRange;
  }

  /// render the picker widget of year、month and day
  Widget _renderDatePickerWidget() {
    final pickers = <Widget>[];
    DateTimeFormatter.splitDateFormat(widget.dateFormat).forEach((format) {
      final valueRange = _findPickerItemRange(format)!;

      final pickerColumn = _renderDatePickerColumnComponent(
        scrollCtrl: _findScrollCtrl(format),
        valueRange: valueRange,
        format: format,
        valueChanged: (value) {
          if (format.contains('y')) {
            _monthLock = true;
            _changeYearSelection(value);
            _monthLock = false;
          } else if (format.contains('M')) {
            if (_monthLock) {
              _monthLock = false;
              return;
            }
            _changeMonthSelection(value);
          } else if (format.contains('d')) {
            _changeDaySelection(value);
          } else if (format.contains('H')) {
            _minuteLock = true;
            _changeHourSelection(value);
            _minuteLock = false;
          } else if (format.contains('m')) {
            if (_minuteLock) {
              _minuteLock = false;
              return;
            }
            _changeMinuteSelection(value);
          }
        },
        fontSize: widget.pickerTheme!.itemTextStyle.fontSize ??
            sizeByFormat(widget.dateFormat!),
      );
      pickers.add(pickerColumn);
    });
    return Padding(
      padding: widget.pickerTheme!.padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: pickers,
      ),
    );
  }

  Widget _renderDatePickerColumnComponent({
    required FixedExtentScrollController? scrollCtrl,
    required List<int> valueRange,
    required String format,
    required ValueChanged<int> valueChanged,
    double? fontSize,
  }) {
    return Expanded(
      child: Stack(
        children: <Widget>[
          Positioned(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 18),
              height: widget.pickerTheme!.pickerHeight,
              decoration:
                  BoxDecoration(color: widget.pickerTheme!.backgroundColor),
              child: CupertinoPicker(
                selectionOverlay: const SizedBox(),
                backgroundColor: widget.pickerTheme!.backgroundColor,
                scrollController: scrollCtrl,
                squeeze: 0.95,
                diameterRatio: 1.5,
                itemExtent: widget.pickerTheme!.itemHeight,
                onSelectedItemChanged: valueChanged,
                looping: widget.looping,
                children: List<Widget>.generate(
                  valueRange.last - valueRange.first + 1,
                  (index) {
                    return _renderDatePickerItemComponent(
                      valueRange.first + index,
                      format,
                      fontSize,
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            child: Container(
              margin: const EdgeInsets.only(top: 63),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                  Expanded(
                    child: Divider(
                      color: widget.pickerTheme!.dividerColor ??
                          Colors.transparent,
                      height: 1,
                      thickness: 2,
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.02)
                ],
              ),
            ),
          ),
          Positioned(
            child: Container(
              margin: const EdgeInsets.only(top: 99),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                  Expanded(
                    child: Divider(
                      color: widget.pickerTheme!.dividerColor ??
                          Colors.transparent,
                      height: 1,
                      thickness: 2,
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double sizeByFormat(String format) {
    if (format.contains("-MMMM") || format.contains("MMMM-"))
      return DATETIME_PICKER_ITEM_TEXT_SIZE_SMALL;

    return DATETIME_PICKER_ITEM_TEXT_SIZE_BIG;
  }

  Widget _renderDatePickerItemComponent(
    int value,
    String format,
    double? fontSize,
  ) {
    final weekday = DateTime(_currYear!, _currMonth!, value).weekday;

    return Container(
      height: widget.pickerTheme!.itemHeight,
      alignment: Alignment.center,
      child: AutoSizeText(
        DateTimeFormatter.formatDateTime(value, format, widget.locale, weekday),
        maxLines: 1,
        // style: TextStyle(
        //     color: widget.pickerTheme!.itemTextStyle.color,
        //     fontSize: fontSize ?? widget.pickerTheme!.itemTextStyle.fontSize
        // ),
        style: widget.pickerTheme?.itemTextStyle ??
            DATETIME_PICKER_ITEM_TEXT_STYLE,
      ),
    );
  }

  /// change the selection of year picker
  void _changeYearSelection(int index) {
    final year = _yearRange!.first + index;
    if (_currYear != year) {
      _currYear = year;
      _changeDateRange();
      _onSelectedChange();
    }
  }

  /// change the selection of month picker
  void _changeMonthSelection(int index) {
    _monthRange = _calcMonthRange();

    final month = _monthRange!.first + index;
    if (_currMonth != month) {
      _currMonth = month;

      _changeDateRange();
      _onSelectedChange();
    }
  }

  /// change the selection of day picker
  void _changeDaySelection(int index) {
    if (_isChangeDateRange) {
      return;
    }

    final dayOfMonth = _dayRange!.first + index;
    if (_currDay != dayOfMonth) {
      _currDay = dayOfMonth;
      _onSelectedChange();
    }
  }

  /// change the selection of day picker
  void _changeHourSelection(int index) {
    if (_isChangeDateRange) {
      return;
    }

    final hour = _hourRange!.first + index;
    if (_currHour != hour) {
      _currHour = hour;
      _changeDateRange();
      _onSelectedChange();
    }
  }

  /// change the selection of day picker
  void _changeMinuteSelection(int index) {
    if (_isChangeDateRange) {
      return;
    }

    final minute = _minuteRange!.first + index;
    if (_currMinute != minute) {
      _currMinute = minute;
      _onSelectedChange();
    }
  }

  // get the correct month
  int? _calcCurrentMonth() {
    int? _currMonth = this._currMonth!;
    final monthRange = _calcMonthRange();
    if (_currMonth < monthRange.last) {
      _currMonth = max(_currMonth, monthRange.first);
    } else {
      _currMonth = max(monthRange.last, monthRange.first);
    }

    return _currMonth;
  }

  // get the correct minute
  int? _calcCurrentMinute() {
    int? _currMinute = this._currMinute!;
    final minuteRange = _calcMinutesRange();
    if (_currMinute < minuteRange.last) {
      _currMinute = max(_currMinute, minuteRange.first);
    } else {
      _currMinute = max(minuteRange.last, minuteRange.first);
    }

    return _currMinute;
  }

  /// change range of month and day
  void _changeDateRange() {
    if (_isChangeDateRange) {
      return;
    }
    _isChangeDateRange = true;

    final monthRange = _calcMonthRange();
    final monthRangeChanged = _monthRange!.first != monthRange.first ||
        _monthRange!.last != monthRange.last;
    if (monthRangeChanged) {
      // selected year changed
      _currMonth = _calcCurrentMonth();
    }

    final dayRange = _calcDayRange();
    final dayRangeChanged =
        _dayRange!.first != dayRange.first || _dayRange!.last != dayRange.last;
    if (dayRangeChanged) {
      // day range changed, need limit the value of selected day
      _currDay = max(min(_currDay!, dayRange.last), dayRange.first);
    }
    final minuteRange = _calcMinutesRange();
    final minuteRangeChanged = _minuteRange!.first != minuteRange.first;
    if (minuteRangeChanged) {
      // minute range changed, need limit the value of selected minute
      _currMinute = _calcCurrentMinute();
    }

    setState(() {
      _monthRange = monthRange;
      _dayRange = dayRange;
      _minuteRange = minuteRange;

      _valueRangeMap['M'] = monthRange;
      _valueRangeMap['d'] = dayRange;
      _valueRangeMap['m'] = minuteRange;
    });

    if (monthRangeChanged) {
      // CupertinoPicker refresh data not working (https://github.com/flutter/flutter/issues/22999)
      final currMonth = _currMonth!;
      _monthScrollCtrl!.jumpToItem(monthRange.last - monthRange.first);
      if (currMonth < monthRange.last) {
        _monthScrollCtrl!.jumpToItem(currMonth - monthRange.first);
      }
    }

    if (dayRangeChanged) {
      // CupertinoPicker refresh data not working (https://github.com/flutter/flutter/issues/22999)
      final currDay = _currDay!;

      if (currDay < dayRange.last) {
        _dayScrollCtrl!.jumpToItem(currDay - dayRange.first);
      } else {
        _dayScrollCtrl!.jumpToItem(dayRange.last - dayRange.first);
      }
    }

    if (minuteRangeChanged) {
      // CupertinoPicker refresh data not working (https://github.com/flutter/flutter/issues/22999)
      final currMinute = _currMinute!;
      //
      if (currMinute < minuteRange.last) {
        _minuteScrollCtrl!.jumpToItem(currMinute - minuteRange.first);
      } else {
        _minuteScrollCtrl!.jumpToItem(minuteRange.last - minuteRange.first);
      }
    }

    _isChangeDateRange = false;
  }

  /// calculate the count of day in current month
  int _calcDayCountOfMonth() {
    if (_currMonth == 2) {
      return isLeapYear(_currYear!) ? 29 : 28;
    } else if (_solarMonthsOf31Days.contains(_currMonth)) {
      return 31;
    }
    return 30;
  }

  /// whether or not is leap year
  bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  }

  /// calculate selected index list
  List<int> _calcSelectIndexList() {
    final yearIndex = _currYear! - _minDateTime.year;
    final monthIndex = _currMonth! - _monthRange!.first;
    final dayIndex = _currDay! - _dayRange!.first;
    final hourIndex = _currHour! - _hourRange!.first;
    final minuteIndex = _currMinute! - _minuteRange!.first;

    return [yearIndex, monthIndex, dayIndex, hourIndex, minuteIndex];
  }

  /// calculate the range of year
  List<int> _calcYearRange() {
    return [_minDateTime.year, _maxDateTime.year];
  }

  /// calculate the range of month
  List<int> _calcMonthRange() {
    int minMonth = 1, maxMonth = 12;
    final minYear = _minDateTime.year;
    final maxYear = _maxDateTime.year;
    if (minYear == _currYear) {
      // selected minimum year, limit month range
      minMonth = _minDateTime.month;
    }
    if (maxYear == _currYear) {
      // selected maximum year, limit month range
      maxMonth = _maxDateTime.month;
    }
    return [minMonth, maxMonth];
  }

  /// calculate the range of day
  List<int> _calcDayRange({int? currMonth}) {
    int minDay = 1, maxDay = _calcDayCountOfMonth();
    final minYear = _minDateTime.year;
    final maxYear = _maxDateTime.year;
    final minMonth = _minDateTime.month;
    final maxMonth = _maxDateTime.month;
    if (currMonth == null) {
      currMonth = _currMonth;
    }
    if (minYear == _currYear && minMonth == currMonth) {
      // selected minimum year and month, limit day range
      minDay = _minDateTime.day;
    }
    if (maxYear == _currYear && maxMonth == currMonth) {
      // selected maximum year and month, limit day range
      maxDay = _maxDateTime.day;
    }
    return [minDay, maxDay];
  }

  List<int> _calcMinutesRange() {
    if (!isLimitHourAndMinuteSelectionBasedOnFirstDate) {
      return [0, 59];
    }
    var minMinutes = 0;
    final minHour = _minDateTime.hour;
    if (minHour == _currHour) {
      // limit minutes range based on hour
      minMinutes = _minDateTime.minute;
    }
    return [minMinutes, 59];
  }
}
