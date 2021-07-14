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
  bool isActive = false;

  UserGraphEntity(
    this.drawType,
    this.values,
  );
}
