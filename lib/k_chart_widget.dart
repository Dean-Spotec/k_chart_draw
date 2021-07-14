import 'dart:async';

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:k_chart/chart_translations.dart';
import 'package:k_chart/entity/draw_graph_entity.dart';
import 'package:k_chart/extension/map_ext.dart';
import 'package:k_chart/flutter_k_chart.dart';

enum MainState { MA, BOLL, NONE }
enum SecondaryState { MACD, KDJ, RSI, WR, CCI, NONE }

class TimeFormat {
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [
    yyyy,
    '-',
    mm,
    '-',
    dd,
    ' ',
    HH,
    ':',
    nn
  ];
}

class KChartWidgetController {
  _KChartWidgetState? _state;

  void bindState(State state) {
    _state = state as _KChartWidgetState?;
  }

  void resetUserGraphs() {
    _state?.resetUserGraphs();
  }

  void removeActiveUserGraph() {
    _state?.removeActiveUserGraph();
  }
}

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? datas;
  final MainState mainState;
  //画图点击事件超出主图范围
  final Function()? outMainTap;
  final bool volHidden;
  final SecondaryState secondaryState;
  final Function()? onSecondaryTap;
  final bool isLine;
  final bool hideGrid;
  @Deprecated('Use `translations` instead.')
  final bool isChinese;
  final Map<String, ChartTranslations> translations;
  final List<String> timeFormat;

  //当屏幕滚动到尽头会调用，真为拉到屏幕右侧尽头，假为拉到屏幕左侧尽头
  final Function(bool)? onLoadMore;
  final List<Color>? bgColor;
  final int fixedLength;
  final List<int> maDayList;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final ChartColors chartColors;
  final ChartStyle chartStyle;

  final KChartWidgetController? controller;
  // 是否是绘图模式，绘图模式长按不显示价格图标。
  final bool isDrawingModel;
  // 绘图类型
  final UserGraphType? userDrawType;
  // 需要绘制的图形
  final List<UserGraphEntity> userGraphs;
  // 完成绘制图形的回调
  final VoidCallback? finishDrawUserGraphs;

  KChartWidget(
    this.datas,
    this.chartStyle,
    this.chartColors, {
    this.mainState = MainState.MA,
    this.outMainTap,
    this.secondaryState = SecondaryState.MACD,
    this.onSecondaryTap,
    this.volHidden = false,
    this.isLine = false,
    this.hideGrid = false,
    this.isChinese = false,
    this.translations = kChartTranslations,
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.onLoadMore,
    this.bgColor,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.controller,
    this.isDrawingModel = false,
    this.userDrawType,
    this.userGraphs = const [],
    this.finishDrawUserGraphs,
  });

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin {
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  StreamController<InfoWindowEntity?>? mInfoWindowStream;
  double mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;
  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false;

  double getMinScrollX() {
    return mScaleX;
  }

  // 当前编辑中的图形
  UserGraphEntity? _drawingUserGraph;
  // 长按手势当前点的value值
  UserGraphRawValue? _currentPressValue;
  // 选中锚点在DrawGraphEntity的value数组中的索引
  int? _pressAnchorIndex;

  @override
  void initState() {
    super.initState();
    widget.controller?.bindState(this);
    mInfoWindowStream = StreamController<InfoWindowEntity?>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    mWidth = MediaQuery.of(context).size.width;
  }

  @override
  void dispose() {
    mInfoWindowStream?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas != null && widget.datas!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    final _painter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      datas: widget.datas,
      scaleX: mScaleX,
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      mainState: widget.mainState,
      volHidden: widget.volHidden,
      secondaryState: widget.secondaryState,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      sink: mInfoWindowStream?.sink,
      bgColor: widget.bgColor,
      fixedLength: widget.fixedLength,
      maDayList: widget.maDayList,
      specifiedPrice: [33100, 29000, 41000],
      userGraphs: widget.userGraphs,
    );
    return GestureDetector(
      onTapUp: (details) {
        if (_painter.isInMainRect(details.localPosition)) {
          _mainRectTapped(_painter, details.localPosition);
        }
        if (widget.onSecondaryTap != null &&
            _painter.isInSecondaryRect(details.localPosition)) {
          widget.onSecondaryTap!();
        }
      },
      onHorizontalDragDown: (details) {
        _stopAnimation();
        _onDragChanged(true);
      },
      onHorizontalDragStart: (_) {
        finishDrawUserGraphs();
      },
      onHorizontalDragUpdate: (details) {
        if (isScale || isLongPress) return;
        mScrollX = (details.primaryDelta! / mScaleX + mScrollX)
            .clamp(0.0, ChartPainter.maxScrollX)
            .toDouble();
        notifyChanged();
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        var velocity = details.velocity.pixelsPerSecond.dx;
        _onFling(velocity);
      },
      onHorizontalDragCancel: () => _onDragChanged(false),
      onScaleStart: (_) {
        isScale = true;
      },
      onScaleUpdate: (details) {
        if (isDrag || isLongPress) return;
        mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
        notifyChanged();
      },
      onScaleEnd: (_) {
        isScale = false;
        _lastScale = mScaleX;
      },
      onLongPressStart: (details) {
        if (widget.isDrawingModel) {
          _beginMoveActiveGraph(_painter, details.localPosition);
        } else {
          isLongPress = true;
          if (mSelectX != details.globalPosition.dx) {
            mSelectX = details.globalPosition.dx;
            notifyChanged();
          }
        }
      },
      onLongPressMoveUpdate: (details) {
        if (widget.isDrawingModel) {
          _moveActiveGraph(_painter, details.localPosition);
        } else {
          if (mSelectX != details.globalPosition.dx) {
            mSelectX = details.globalPosition.dx;
            notifyChanged();
          }
        }
      },
      onLongPressEnd: (details) {
        if (widget.isDrawingModel) {
          _currentPressValue = null;
        } else {
          isLongPress = false;
          mInfoWindowStream?.sink.add(null);
          notifyChanged();
        }
      },
      child: Stack(
        children: <Widget>[
          CustomPaint(
            size: Size(double.infinity, double.infinity),
            painter: _painter,
          ),
          _buildInfoDialog()
        ],
      ),
    );
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _mainRectTapped(ChartPainter painter, Offset touchPoint) {
    if (!widget.isDrawingModel) {
      return;
    }
    if (widget.userDrawType == null) {
      painter.detectUserGraphs(touchPoint);
      setState(() {});
    } else {
      _drawUserGraph(painter, touchPoint);
    }
  }

  void _drawUserGraph(ChartPainter painter, Offset touchPoint) {
    switch (widget.userDrawType!) {
      case UserGraphType.segmentLine:
      case UserGraphType.rayLine:
      case UserGraphType.straightLine:
      case UserGraphType.rectangle:
        _drawTwoAnchorUserGraph(painter, touchPoint);
        break;
    }
  }

  // 绘制只有两个锚点的图形
  void _drawTwoAnchorUserGraph(ChartPainter painter, Offset touchPoint) {
    if (_drawingUserGraph == null) {
      _drawingUserGraph = UserGraphEntity(widget.userDrawType!, []);
      _drawingUserGraph?.isActive = true;
      widget.userGraphs.add(_drawingUserGraph!);
    }
    if (_drawingUserGraph!.values.length < 2) {
      var value = painter.calculateTouchRawValue(touchPoint);
      if (value == null) {
        if (widget.outMainTap != null) {
          widget.outMainTap!();
        }
      } else {
        _drawingUserGraph!.values.add(value);
      }
      widget.userGraphs.last = _drawingUserGraph!;
      notifyChanged();
    } else {
      finishDrawUserGraphs();
    }
  }

  // 用户完成图形绘制
  void finishDrawUserGraphs() {
    if (_drawingUserGraph == null) {
      return;
    }
    // length>=2才是有效图形
    if (_drawingUserGraph!.values.length >= 2) {
      _drawingUserGraph = null;
      widget.userGraphs.last.isActive = false;
      widget.finishDrawUserGraphs?.call();
    }
  }

  // 重置用户绘制图形状态。对于绘制中的图形，如果是有效图形则将其保存
  void resetUserGraphs() {
    widget.userGraphs.forEach((graph) => graph.isActive = false);
    if (_drawingUserGraph == null) {
      return;
    }
    if (_drawingUserGraph!.values.length < 2) {
      // 删除无效图形
      widget.userGraphs.removeLast();
    } else {
      widget.userGraphs.lastOrNull?.isActive = false;
    }
    _drawingUserGraph = null;
  }

  // 移除绘制中的、编辑中的图形
  void removeActiveUserGraph() {
    if (_drawingUserGraph == null) {
      widget.userGraphs.removeWhere((graph) => graph.isActive);
    } else {
      widget.userGraphs.removeLast();
      _drawingUserGraph = null;
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag!(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
        duration: Duration(milliseconds: widget.flingTime), vsync: this);
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(CurvedAnimation(
            parent: _controller!.view, curve: widget.flingCurve));
    aniX!.addListener(() {
      mScrollX = aniX!.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(true);
        }
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX) {
        mScrollX = ChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(false);
        }
        _stopAnimation();
      }
      notifyChanged();
    });
    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller!.forward();
  }

  // 长按开始移动正在编辑的图形
  void _beginMoveActiveGraph(ChartPainter painter, Offset position) {
    if (!painter.canBeginMoveActiveGraph(position)) {
      return;
    }
    _currentPressValue = painter.calculateTouchRawValue(position);
    _pressAnchorIndex = painter.detectAnchorPointIndex(position);
  }

  // 移动正在编辑的图形
  void _moveActiveGraph(ChartPainter painter, Offset position) {
    if (_currentPressValue == null || !painter.canMoveActiveGraph()) {
      return;
    }
    var nextValue = painter.calculateMoveRawValue(position);
    painter.moveActiveGraph(_currentPressValue!, nextValue, _pressAnchorIndex);
    _currentPressValue = nextValue;
    notifyChanged();
  }

  void notifyChanged() => setState(() {});

  late List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
        stream: mInfoWindowStream?.stream,
        builder: (context, snapshot) {
          if (!isLongPress ||
              widget.isLine == true ||
              !snapshot.hasData ||
              snapshot.data?.kLineEntity == null) return Container();
          KLineEntity entity = snapshot.data!.kLineEntity;
          double upDown = entity.change ?? entity.close - entity.open;
          double upDownPercent = entity.ratio ?? (upDown / entity.open) * 100;
          infos = [
            getDate(entity.time),
            entity.open.toStringAsFixed(widget.fixedLength),
            entity.high.toStringAsFixed(widget.fixedLength),
            entity.low.toStringAsFixed(widget.fixedLength),
            entity.close.toStringAsFixed(widget.fixedLength),
            "${upDown > 0 ? "+" : ""}${upDown.toStringAsFixed(widget.fixedLength)}",
            "${upDownPercent > 0 ? "+" : ''}${upDownPercent.toStringAsFixed(2)}%",
            entity.amount.toInt().toString()
          ];
          return Container(
            margin: EdgeInsets.only(
                left: snapshot.data!.isLeft ? 4 : mWidth - mWidth / 3 - 4,
                top: 25),
            width: mWidth / 3,
            decoration: BoxDecoration(
                color: widget.chartColors.selectFillColor,
                border: Border.all(
                    color: widget.chartColors.selectBorderColor, width: 0.5)),
            child: ListView.builder(
              padding: EdgeInsets.all(4),
              itemCount: infos.length,
              itemExtent: 14.0,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final translations = widget.isChinese
                    ? kChartTranslations['zh_CN']!
                    : widget.translations.of(context);

                return _buildItem(
                  infos[index],
                  translations.byIndex(index),
                );
              },
            ),
          );
        });
  }

  Widget _buildItem(String info, String infoName) {
    Color color = widget.chartColors.infoWindowNormalColor;
    if (info.startsWith("+"))
      color = widget.chartColors.infoWindowUpColor;
    else if (info.startsWith("-"))
      color = widget.chartColors.infoWindowDnColor;
    else
      color = widget.chartColors.infoWindowNormalColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
            child: Text("$infoName",
                style: TextStyle(
                    color: widget.chartColors.infoWindowTitleColor,
                    fontSize: 10.0))),
        Text(info, style: TextStyle(color: color, fontSize: 10.0)),
      ],
    );
  }

  String getDate(int? date) => dateFormat(
      DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch),
      widget.timeFormat);
}
