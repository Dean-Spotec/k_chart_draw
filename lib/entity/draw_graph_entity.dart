enum UserGraphType {
  segmentLine,
  rayLine,
  straightLine,
  rectangle,
}

class UserGraphRawValue {
  double index;
  double price;

  UserGraphRawValue(
    this.index,
    this.price,
  );
}

class UserGraphEntity {
  UserGraphType drawType;
  List<UserGraphRawValue> values;

  UserGraphEntity(
    this.drawType,
    this.values,
  );
}
