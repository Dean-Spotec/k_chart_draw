enum DrawGraphType {
  segmentLine,
  rayLine,
  straightLine,
  rectangle,
}

class DrawGraphRawValue {
  double index;
  double price;

  DrawGraphRawValue(
    this.index,
    this.price,
  );
}

class DrawGraphEntity {
  DrawGraphType drawType;
  List<DrawGraphRawValue> values;

  DrawGraphEntity(
    this.drawType,
    this.values,
  );
}
