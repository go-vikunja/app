class Filter {
  final String s;
  String? sortBy;
  String? orderBy;
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
