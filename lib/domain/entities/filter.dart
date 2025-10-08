class Filter {
  final String s;
  List<String>? sortBy;
  List<String>? orderBy;
  String filter;
  bool filterIncludesNulls;

  Filter(
    this.s,
    this.sortBy,
    this.orderBy,
    this.filter,
    this.filterIncludesNulls,
  );
}
