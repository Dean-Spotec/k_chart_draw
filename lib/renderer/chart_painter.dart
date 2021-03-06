import 'dart:async' show StreamSink;

import 'package:flutter/material.dart';
import 'package:k_chart/entity/draw_graph_entity.dart';
import 'package:k_chart/utils/distance_util.dart';
import 'package:k_chart/utils/number_util.dart';
import 'package:collection/collection.dart';

import '../entity/info_window_entity.dart';
import '../entity/k_line_entity.dart';
import '../utils/date_format_util.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
import 'vol_renderer.dart';

class ChartPainter extends BaseChartPainter {
  static get maxScrollX => BaseChartPainter.maxScrollX;
  late MainRenderer mMainRenderer;
  BaseChartRenderer? mVolRenderer, mSecondaryRenderer;
  StreamSink<InfoWindowEntity?>? sink;
  Color? upColor, dnColor;
  Color? ma5Color, ma10Color, ma30Color;
  Color? volColor;
  Color? macdColor, difColor, deaColor, jColor;
  List<Color>? bgColor;
  int fixedLength;
  List<int> maDayList;
  final ChartColors chartColors;
  Paint? selectPointPaint, selectorBorderPaint;
  final ChartStyle chartStyle;
  final bool hideGrid;
  final bool isDrawingModel;
  final List<double>? specifiedPrice;
  final List<UserGraphEntity> userGraphs;

  final _graphDetectWidth = 5.0;
  // 可编辑的用户图形
  UserGraphEntity? _activeUserGraph;
  var _twinklPaint = Paint();
  var _realTimePaint = Paint()
    ..strokeWidth = 1.0
    ..isAntiAlias = true;

  ChartPainter(
    this.chartStyle,
    this.chartColors, {
    required datas,
    required scaleX,
    required scrollX,
    required isLongPass,
    required selectX,
    mainState,
    volHidden,
    secondaryState,
    this.sink,
    bool isLine = false,
    this.hideGrid = false,
    this.bgColor,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
    this.specifiedPrice,
    this.isDrawingModel = false,
    this.userGraphs = const [],
  })  : assert(bgColor == null || bgColor.length >= 2),
        super(chartStyle,
            datas: datas,
            scaleX: scaleX,
            scrollX: scrollX,
            isLongPress: isLongPass,
            selectX: selectX,
            mainState: mainState,
            volHidden: volHidden,
            secondaryState: secondaryState,
            isLine: isLine) {
    selectPointPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..color = this.chartColors.selectFillColor;
    selectorBorderPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..color = this.chartColors.selectBorderColor;
    _activeUserGraph = userGraphs.firstWhereOrNull((grapa) => grapa.isActive);
  }

  @override
  void initChartRenderer() {
    if (datas != null) {
      var t = datas![0];
      fixedLength =
          NumberUtil.getMaxDecimalLength(t.open, t.close, t.high, t.low);
    }
    mMainRenderer = MainRenderer(
      mMainRect,
      mMainMaxValue,
      mMainMinValue,
      mTopPadding,
      mainState,
      isLine,
      fixedLength,
      this.chartStyle,
      this.chartColors,
      this.scaleX,
      maDayList,
    );
    if (mVolRect != null) {
      mVolRenderer = VolRenderer(mVolRect!, mVolMaxValue, mVolMinValue,
          mChildPadding, fixedLength, this.chartStyle, this.chartColors);
    }
    if (mSecondaryRect != null) {
      mSecondaryRenderer = SecondaryRenderer(
          mSecondaryRect!,
          mSecondaryMaxValue,
          mSecondaryMinValue,
          mChildPadding,
          secondaryState,
          fixedLength,
          chartStyle,
          chartColors);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);
    _drawSpecifiedPrices(canvas);
    _drawUserGraph(canvas);
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    Paint mBgPaint = Paint();
    Gradient mBgGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: bgColor ?? [Color(0xff18191d), Color(0xff18191d)],
    );
    Rect mainRect =
        Rect.fromLTRB(0, 0, mMainRect.width, mMainRect.height + mTopPadding);
    canvas.drawRect(
        mainRect, mBgPaint..shader = mBgGradient.createShader(mainRect));

    if (mVolRect != null) {
      Rect volRect = Rect.fromLTRB(
          0, mVolRect!.top - mChildPadding, mVolRect!.width, mVolRect!.bottom);
      canvas.drawRect(
          volRect, mBgPaint..shader = mBgGradient.createShader(volRect));
    }

    if (mSecondaryRect != null) {
      Rect secondaryRect = Rect.fromLTRB(0, mSecondaryRect!.top - mChildPadding,
          mSecondaryRect!.width, mSecondaryRect!.bottom);
      canvas.drawRect(secondaryRect,
          mBgPaint..shader = mBgGradient.createShader(secondaryRect));
    }
    Rect dateRect =
        Rect.fromLTRB(0, size.height - mBottomPadding, size.width, size.height);
    canvas.drawRect(
        dateRect, mBgPaint..shader = mBgGradient.createShader(dateRect));
  }

  @override
  void drawGrid(canvas) {
    if (!hideGrid) {
      mMainRenderer.drawGrid(
          canvas, ChartStyle.gridRows, ChartStyle.gridColumns);
      mVolRenderer?.drawGrid(
          canvas, ChartStyle.gridRows, ChartStyle.gridColumns);
      mSecondaryRenderer?.drawGrid(
          canvas, ChartStyle.gridRows, ChartStyle.gridColumns);
    }
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);
    for (int i = mStartIndex; datas != null && i <= mStopIndex; i++) {
      KLineEntity? curPoint = datas?[i];
      if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : datas![i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);

      mMainRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mSecondaryRenderer?.drawChart(
          lastPoint, curPoint, lastX, curX, size, canvas);
    }

    if (isLongPress == true) drawCrossLine(canvas, size);
    canvas.restore();
  }

  @override
  void drawRightText(canvas) {
    var textStyle = getTextStyle(this.chartColors.defaultTextColor);
    mMainRenderer.drawRightText(canvas, textStyle, ChartStyle.gridRows);
    mVolRenderer?.drawRightText(canvas, textStyle, ChartStyle.gridRows);
    mSecondaryRenderer?.drawRightText(canvas, textStyle, ChartStyle.gridRows);
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    double columnSpace = size.width / ChartStyle.gridColumns;
    double startX = getX(mStartIndex) - mPointWidth / 2;
    double stopX = getX(mStopIndex) + mPointWidth / 2;
    double y = 0.0;
    for (var i = 0; i <= ChartStyle.gridColumns; ++i) {
      double translateX = xToTranslateX(columnSpace * i);
      if (translateX >= startX && translateX <= stopX) {
        int index = indexOfTranslateX(translateX);
        if (datas?[index] == null) continue;
        TextPainter tp = getTextPainter(getDate(datas![index].time), null);
        y = size.height - (mBottomPadding - tp.height) / 2 - tp.height;
        tp.paint(canvas, Offset(columnSpace * i - tp.width / 2, y));
      }
    }

//    double translateX = xToTranslateX(0);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStartIndex].id));
//      tp.paint(canvas, Offset(0, y));
//    }
//    translateX = xToTranslateX(size.width);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStopIndex].id));
//      tp.paint(canvas, Offset(size.width - tp.width, y));
//    }
  }

  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);

    TextPainter tp = getTextPainter(point.close, chartColors.crossTextColor);
    double textHeight = tp.height;
    double textWidth = tp.width;

    double w1 = 5;
    double w2 = 3;
    double r = textHeight / 2 + w2;
    double y = getMainY(point.close);
    double x;
    bool isLeft = false;
    if (translateXtoX(getX(index)) < mWidth / 2) {
      isLeft = false;
      x = 1;
      Path path = new Path();
      path.moveTo(x, y - r);
      path.lineTo(x, y + r);
      path.lineTo(textWidth + 2 * w1, y + r);
      path.lineTo(textWidth + 2 * w1 + w2, y);
      path.lineTo(textWidth + 2 * w1, y - r);
      path.close();
      canvas.drawPath(path, selectPointPaint!);
      canvas.drawPath(path, selectorBorderPaint!);
      tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
    } else {
      isLeft = true;
      x = mWidth - textWidth - 1 - 2 * w1 - w2;
      Path path = new Path();
      path.moveTo(x, y);
      path.lineTo(x + w2, y + r);
      path.lineTo(mWidth - 2, y + r);
      path.lineTo(mWidth - 2, y - r);
      path.lineTo(x + w2, y - r);
      path.close();
      canvas.drawPath(path, selectPointPaint!);
      canvas.drawPath(path, selectorBorderPaint!);
      tp.paint(canvas, Offset(x + w1 + w2, y - textHeight / 2));
    }

    TextPainter dateTp =
        getTextPainter(getDate(point.time), chartColors.crossTextColor);
    textWidth = dateTp.width;
    r = textHeight / 2;
    x = translateXtoX(getX(index));
    y = size.height - mBottomPadding;

    if (x < textWidth + 2 * w1) {
      x = 1 + textWidth / 2 + w1;
    } else if (mWidth - x < textWidth + 2 * w1) {
      x = mWidth - 1 - textWidth / 2 - w1;
    }
    double baseLine = textHeight / 2;
    canvas.drawRect(
        Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
            y + baseLine + r),
        selectPointPaint!);
    canvas.drawRect(
        Rect.fromLTRB(x - textWidth / 2 - w1, y, x + textWidth / 2 + w1,
            y + baseLine + r),
        selectorBorderPaint!);

    dateTp.paint(canvas, Offset(x - textWidth / 2, y));
    //长按显示这条数据详情
    sink?.add(InfoWindowEntity(point, isLeft: isLeft));
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    //长按显示按中的数据
    if (isLongPress) {
      var index = calculateSelectedX(selectX);
      data = getItem(index);
    }
    //松开显示最后一条数据
    mMainRenderer.drawText(canvas, data, x);
    mVolRenderer?.drawText(canvas, data, x);
    mSecondaryRenderer?.drawText(canvas, data, x);
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine == true) return;
    //绘制最大值和最小值
    double x = translateXtoX(getX(mMainMinIndex));
    double y = getMainY(mMainLowMinValue);
    if (x < mWidth / 2) {
      //画右边
      TextPainter tp = getTextPainter(
          "── " + mMainLowMinValue.toStringAsFixed(fixedLength),
          chartColors.minColor);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
          mMainLowMinValue.toStringAsFixed(fixedLength) + " ──",
          chartColors.minColor);
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
    x = translateXtoX(getX(mMainMaxIndex));
    y = getMainY(mMainHighMaxValue);
    if (x < mWidth / 2) {
      //画右边
      TextPainter tp = getTextPainter(
          "── " + mMainHighMaxValue.toStringAsFixed(fixedLength),
          chartColors.maxColor);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
          mMainHighMaxValue.toStringAsFixed(fixedLength) + " ──",
          chartColors.maxColor);
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
  }

  ///画交叉线
  void drawCrossLine(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);
    Paint paintY = Paint()
      ..color = this.chartColors.vCrossColor
      ..strokeWidth = this.chartStyle.vCrossWidth
      ..isAntiAlias = true;
    double x = getX(index);
    double y = getMainY(point.close);
    // k线图竖线
    canvas.drawLine(Offset(x, mTopPadding),
        Offset(x, size.height - mBottomPadding), paintY);

    Paint paintX = Paint()
      ..color = this.chartColors.hCrossColor
      ..strokeWidth = this.chartStyle.hCrossWidth
      ..isAntiAlias = true;
    // k线图横线
    canvas.drawLine(Offset(-mTranslateX, y),
        Offset(-mTranslateX + mWidth / scaleX, y), paintX);
    if (scaleX >= 1) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), height: 2.0 * scaleX, width: 2.0),
          paintX);
    } else {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), height: 2.0, width: 2.0 / scaleX),
          paintX);
    }
  }

  ///画实时价格线
  @override
  void drawRealTimePrice(Canvas canvas) {
    if (mMarginRight == 0 || datas == null || datas?.isEmpty == true) return;
    KLineEntity point = datas!.last;
    TextPainter tp =
        getTextPainter(format(point.close), ChartColors.rightRealTimeTextColor);
    double y = getMainY(point.close);
    //max越往右边滑值越小
    var max = (mTranslateX.abs() +
            mMarginRight -
            getMinTranslateX().abs() +
            mPointWidth) *
        scaleX;
    double x = mWidth - max;
    if (!isLine) x += mPointWidth / 2;
    var dashWidth = 10;
    var dashSpace = 5;
    double startX = 0;
    final space = (dashSpace + dashWidth);
    if (tp.width < max) {
      while (startX < max) {
        canvas.drawLine(
            Offset(x + startX, y),
            Offset(x + startX + dashWidth, y),
            _realTimePaint..color = ChartColors.realTimeLineColor);
        startX += space;
      }
      //画一闪一闪
      if (isLine) {
        // startAnimation();
        Gradient pointGradient =
            RadialGradient(colors: [Colors.white, Colors.transparent]);
        _twinklPaint.shader = pointGradient
            .createShader(Rect.fromCircle(center: Offset(x, y), radius: 14.0));
        canvas.drawCircle(Offset(x, y), 14.0, _twinklPaint);
        canvas.drawCircle(
            Offset(x, y), 2.0, _realTimePaint..color = Colors.white);
      } else {
        // stopAnimation(); //停止一闪闪
      }
      double left = mWidth - tp.width;
      double top = y - tp.height / 2;
      canvas.drawRect(
          Rect.fromLTRB(left, top, left + tp.width, top + tp.height),
          _realTimePaint..color = ChartColors.realTimeBgColor);
      tp.paint(canvas, Offset(left, top));
    } else {
      startX = 0;
      if (point.close > mMainMaxValue) {
        y = getMainY(mMainMaxValue);
      } else if (point.close < mMainMinValue) {
        y = getMainY(mMainMinValue);
      }
      while (startX < mWidth) {
        canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y),
            _realTimePaint..color = ChartColors.realTimeLongLineColor);
        startX += space;
      }

      const padding = 3.0;
      const triangleHeight = 8.0; //三角高度
      const triangleWidth = 5.0; //三角宽度

      double left =
          mWidth - mWidth / ChartStyle.gridColumns - tp.width / 2 - padding * 2;
      double top = y - tp.height / 2 - padding;
      //加上三角形的宽以及padding
      double right = left + tp.width + padding * 2 + triangleWidth + padding;
      double bottom = top + tp.height + padding * 2;
      double radius = (bottom - top) / 2;
      //画椭圆背景
      RRect rectBg1 =
          RRect.fromLTRBR(left, top, right, bottom, Radius.circular(radius));
      RRect rectBg2 = RRect.fromLTRBR(left - 1, top - 1, right + 1, bottom + 1,
          Radius.circular(radius + 2));
      canvas.drawRRect(
          rectBg2, _realTimePaint..color = ChartColors.realTimeTextBorderColor);
      canvas.drawRRect(
          rectBg1, _realTimePaint..color = ChartColors.realTimeBgColor);
      tp = getTextPainter(format(point.close), ChartColors.realTimeTextColor);
      Offset textOffset = Offset(left + padding, y - tp.height / 2);
      tp.paint(canvas, textOffset);
      //画三角
      Path path = Path();
      double dx = tp.width + textOffset.dx + padding;
      double dy = top + (bottom - top - triangleHeight) / 2;
      path.moveTo(dx, dy);
      path.lineTo(dx + triangleWidth, dy + triangleHeight / 2);
      path.lineTo(dx, dy + triangleHeight);
      path.close();
      canvas.drawPath(
          path,
          _realTimePaint
            ..color = ChartColors.realTimeTextColor
            ..shader = null);
    }
  }

  void _drawSpecifiedPrices(Canvas canvas) {
    if (specifiedPrice == null) return;
    var dashWidth = 10;
    var dashSpace = 5;
    var space = (dashSpace + dashWidth);
    for (var price in specifiedPrice!) {
      double startX = 0;
      double y = getMainY(price);
      while (startX < mWidth) {
        canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y),
            _realTimePaint..color = ChartColors.realTimeLongLineColor);
        startX += space;
      }
      TextPainter tp =
          getTextPainter(format(price), ChartColors.rightRealTimeTextColor);
      Offset textOffset = Offset(5, y - tp.height - 2);
      tp.paint(canvas, textOffset);
    }
  }

  TextPainter getTextPainter(text, color) {
    if (color == null) {
      color = this.chartColors.defaultTextColor;
    }
    TextSpan span = TextSpan(text: "$text", style: getTextStyle(color));
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  String getDate(int? date) => dateFormat(
      DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch),
      mFormats);

  double getMainY(double y) => mMainRenderer.getY(y);
  double getMainPrice(double y) => mMainRenderer.getPrice(y);

  /// 点是否在MainRect中
  bool isInMainRect(Offset point) {
    return mMainRect.contains(point);
  }

  /// 点是否在SecondaryRect中
  bool isInSecondaryRect(Offset point) {
    return mSecondaryRect?.contains(point) ?? false;
  }

  final _graphPaint = Paint()
    ..strokeWidth = 1.0
    ..isAntiAlias = true
    ..color = Colors.red;

  // 计算点击手势的点在k线图中对应的index和价格
  UserGraphRawValue? calculateTouchRawValue(Offset touchPoint) {
    var index = getDoubleIndex(touchPoint.dx / scaleX - mTranslateX);
    var price = getMainPrice(touchPoint.dy);
    return UserGraphRawValue(index, price);
  }

  // 计算移动手势的点在k线图中对应的index和价格
  UserGraphRawValue calculateMoveRawValue(Offset movePoint) {
    var index = getDoubleIndex(movePoint.dx / scaleX - mTranslateX);
    var dy = movePoint.dy;
    if (movePoint.dy < mMainRect.top) {
      dy = mMainRect.top;
    }
    if (movePoint.dy > mMainRect.bottom) {
      dy = mMainRect.bottom;
    }
    var price = getMainPrice(dy);
    return UserGraphRawValue(index, price);
  }

  // 用户手动绘制的图形
  void _drawUserGraph(Canvas canvas) {
    canvas.save();
    canvas.clipRect(mMainRect);
    //绘制没有交互的图形
    userGraphs.forEach((graph) {
      _drawSingleGraph(canvas, graph);
    });
    _drawGraphAnchorPoints(canvas);
    canvas.restore();
  }

  // 绘制单个图形
  void _drawSingleGraph(Canvas canvas, UserGraphEntity? graph) {
    if (graph == null) {
      return;
    }
    var points = graph.values.map((value) {
      double dx = translateXtoX(getXFromDouble(value.index));
      double dy = getMainY(value.price);
      return Offset(dx, dy);
    }).toList();
    // 两点相同则不绘制
    if (points.length < 2 || points.first == points.last) {
      return;
    }
    switch (graph.drawType) {
      case UserGraphType.segmentLine:
        _drawSegmentLine(canvas, points);
        break;
      case UserGraphType.rayLine:
        _drawRayLine(canvas, points);
        break;
      case UserGraphType.straightLine:
        _drawStraightLine(canvas, points);
        break;
      case UserGraphType.rectangle:
        _drawRectangle(canvas, points);
        break;
      default:
    }
  }

  // 绘制单个图形的锚点
  void _drawGraphAnchorPoints(Canvas canvas) {
    _activeUserGraph?.values.forEach((value) {
      double dx = translateXtoX(getXFromDouble(value.index));
      double dy = getMainY(value.price);
      canvas.drawCircle(Offset(dx, dy), _graphDetectWidth, _graphPaint);
    });
  }

  // 绘制线段
  void _drawSegmentLine(Canvas canvas, List<Offset> points) {
    canvas.drawLine(points.first, points.last, _graphPaint);
  }

  // 绘制射线
  void _drawRayLine(Canvas canvas, List<Offset> points) {
    var p1 = points.first;
    var p2 = points.last;
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);

    Offset endPoint;
    if (p1.dx < p2.dx) {
      // 端点在画布右侧
      endPoint = rightEdgePoint;
    } else {
      // 端点在画布左侧
      endPoint = leftEdgePoint;
    }
    canvas.drawLine(p1, endPoint, _graphPaint);
  }

  // 绘制直线
  void _drawStraightLine(Canvas canvas, List<Offset> points) {
    var p1 = points.first;
    var p2 = points.last;
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);
    canvas.drawLine(leftEdgePoint, rightEdgePoint, _graphPaint);
  }

  // 绘制矩形
  void _drawRectangle(Canvas canvas, List<Offset> points) {
    var rect = Rect.fromPoints(points.first, points.last);
    canvas.drawRect(rect, _graphPaint);
  }

  // 直线和画板左侧的交点
  Offset _getLeftEdgePoint(Offset p1, Offset p2) {
    var y = _getYPositionInLine(0, p1, p2);
    return Offset(0, y);
  }

  // 直线和画板右侧的交点
  Offset _getRightEdgePoint(Offset p1, Offset p2) {
    var y = _getYPositionInLine(mWidth, p1, p2);
    return Offset(mWidth, y);
  }

  // 根据x值，计算直线和画板交点的y值
  double _getYPositionInLine(double x, Offset p1, Offset p2) {
    // 直线的一般式表达式：Ax+By+C=0
    var x1 = p1.dx;
    var y1 = p1.dy;
    var x2 = p2.dx;
    var y2 = p2.dy;
    var A = y2 - y1;
    var B = x1 - x2;
    var C = x2 * y1 - x1 * y2;
    return -(A * x + C) / B;
  }

  // 根据touch点，查找离它最近的非编辑中的图形
  void detectUserGraphs(Offset touchPoint) {
    if (userGraphs.isEmpty) {
      return;
    }
    userGraphs.forEach((grap) => grap.isActive = false);
    var detectedLine = _detectSingleLine(touchPoint);
    if (detectedLine) {
      return;
    }
    var detectedRectangle = _detectRectangle(touchPoint);
    if (detectedRectangle) {
      return;
    }
  }

  // 根据touch点查找线形，如果找到返回true
  bool _detectSingleLine(Offset touchPoint) {
    var singleLineGraphs = userGraphs.where((graph) {
      switch (graph.drawType) {
        case UserGraphType.segmentLine:
        case UserGraphType.rayLine:
        case UserGraphType.straightLine:
          return true;
        default:
          return false;
      }
    }).toList();

    var minIndex = 0;
    var minDis = double.infinity;
    for (var i = 0; i < singleLineGraphs.length; i++) {
      var distance = _distanceToSingleLine(touchPoint, singleLineGraphs[i]);
      if (distance < minDis) {
        minIndex = i;
        minDis = distance;
      }
    }
    if (minDis < _graphDetectWidth) {
      var graph = singleLineGraphs[minIndex];
      graph.isActive = true;
      _activeUserGraph = graph;
      return true;
    }
    return false;
  }

  // 根据touch点查找矩形，如果找到返回true
  bool _detectRectangle(Offset touchPoint) {
    for (var graph in userGraphs.reversed) {
      if (graph.drawType == UserGraphType.rectangle &&
          _isPointInRectangle(touchPoint, graph)) {
        graph.isActive = true;
        _activeUserGraph = graph;
        return true;
      }
    }
    return false;
  }

  // 根据press点，查找离它最近的锚点的index
  int? detectAnchorPointIndex(Offset touchPoint) {
    if (_activeUserGraph == null) {
      return null;
    }
    var anchorValues = _activeUserGraph!.values;
    var minIndex = 0;
    var minDis = double.infinity;
    for (var i = 0; i < anchorValues.length; i++) {
      var distance = _distanceToGraphAnchorPoint(touchPoint, anchorValues[i]);
      if (distance < minDis) {
        minIndex = i;
        minDis = distance;
      }
    }
    if (minDis < _graphDetectWidth) {
      return minIndex;
    }
  }

  // 根据长按开始点计算编辑中图形是否可以移动
  bool canBeginMoveActiveGraph(Offset touchPoint) {
    if (_activeUserGraph == null) {
      return false;
    }
    switch (_activeUserGraph!.drawType) {
      case UserGraphType.segmentLine:
      case UserGraphType.rayLine:
      case UserGraphType.straightLine:
        var distance = _distanceToSingleLine(touchPoint, _activeUserGraph!);
        return distance < _graphDetectWidth;
      case UserGraphType.rectangle:
        return _isPointInRectangle(touchPoint, _activeUserGraph!);
      default:
        return false;
    }
  }

  bool canMoveActiveGraph() {
    return _activeUserGraph != null;
  }

  void moveActiveGraph(UserGraphRawValue currentValue,
      UserGraphRawValue nextValue, int? anchorIndex) {
    // 计算和上一个点的偏移
    var offset = Offset(nextValue.index - currentValue.index,
        nextValue.price - currentValue.price);
    if (anchorIndex == null) {
      _activeUserGraph?.values.forEach((value) {
        value.index += offset.dx;
        value.price += offset.dy;
      });
    } else {
      _activeUserGraph!.values[anchorIndex].index += offset.dx;
      _activeUserGraph!.values[anchorIndex].price += offset.dy;
    }
  }

  // 点是否在矩形中
  bool _isPointInRectangle(Offset touchPoint, UserGraphEntity graph) {
    var value1 = graph.values.first;
    var value2 = graph.values.last;
    var p1 = Offset(
        translateXtoX(getXFromDouble(value1.index)), getMainY(value1.price));
    var p2 = Offset(
        translateXtoX(getXFromDouble(value2.index)), getMainY(value2.price));
    var valueRect = Rect.fromPoints(p1, p2).inflate(_graphDetectWidth);
    return valueRect.contains(touchPoint);
  }

  // 点到线形的距离
  double _distanceToSingleLine(Offset touchPoint, UserGraphEntity graph) {
    var value1 = graph.values.first;
    var value2 = graph.values.last;
    var p1 = Offset(
        translateXtoX(getXFromDouble(value1.index)), getMainY(value1.price));
    var p2 = Offset(
        translateXtoX(getXFromDouble(value2.index)), getMainY(value2.price));
    var leftEdgePoint = _getLeftEdgePoint(p1, p2);
    var rightEdgePoint = _getRightEdgePoint(p1, p2);

    switch (graph.drawType) {
      case UserGraphType.segmentLine:
        return DistanceUtil.distanceToSegment(touchPoint, p1, p2);
      case UserGraphType.rayLine:
        if (p1.dx < p2.dx) {
          // 端点在画布右侧
          return DistanceUtil.distanceToSegment(touchPoint, p1, rightEdgePoint);
        } else {
          // 端点在画布左侧
          return DistanceUtil.distanceToSegment(touchPoint, leftEdgePoint, p1);
        }
      case UserGraphType.straightLine:
        return DistanceUtil.distanceToSegment(
            touchPoint, leftEdgePoint, rightEdgePoint);
      default:
        return double.infinity;
    }
  }

  // 点到各种形状的锚点的距离
  double _distanceToGraphAnchorPoint(
      Offset touchPoint, UserGraphRawValue anchorValue) {
    var anchorPoint = Offset(translateXtoX(getXFromDouble(anchorValue.index)),
        getMainY(anchorValue.price));
    return DistanceUtil.distanceToPoint(touchPoint, anchorPoint);
  }
}
