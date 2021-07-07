enum DrawGraphType {
  segmentLine,
  rayLine,
  straightLine,
  rectangle,
}

class DrawGraphValue {
  int index;
  double price;

  DrawGraphValue(
    this.index,
    this.price,
  );
}

class DrawGraphEntity {
  DrawGraphType drawType;
  List<DrawGraphValue> values;

  DrawGraphEntity(
    this.drawType,
    this.values,
  );
}
