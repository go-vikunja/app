import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/domain/entities/filter.dart';

class FilterDto extends Dto<Filter> {
  final String s;
  String? sortBy;
  String? orderBy;
  String filter;
  bool filterIncludesNulls;

  FilterDto(
    this.s,
    this.sortBy,
    this.orderBy,
    this.filter,
    this.filterIncludesNulls,
  );

  FilterDto.fromJson(Map<String, dynamic> json)
    : s = json['s'],
      sortBy = json['sort_by'],
      orderBy = json['order_by'],
      filter = json['filter'],
      filterIncludesNulls = json['filter_include_nulls'];

  Map<String, dynamic> toJSON() => {
    's': s,
    'sortBy': sortBy,
    'orderBy': orderBy,
    'filter': filter,
    'filterIncludesNulls': filterIncludesNulls,
  };

  @override
  Filter toDomain() => Filter(s, sortBy, orderBy, filter, filterIncludesNulls);

  static FilterDto fromDomain(Filter p) =>
      FilterDto(p.s, p.sortBy, p.orderBy, p.filter, p.filterIncludesNulls);
}
