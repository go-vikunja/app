priorityToString(int? priority) {
  switch (priority) {
    case 0:
      return 'Unset';
    case 1:
      return 'Low';
    case 2:
      return 'Medium';
    case 3:
      return 'High';
    case 4:
      return 'Urgent';
    case 5:
      return 'DO NOW';
    default:
      return "";
  }
}

// FIXME: Move the following two functions to an extra class or type.
priorityFromString(String? priority) {
  switch (priority) {
    case 'Low':
      return 1;
    case 'Medium':
      return 2;
    case 'High':
      return 3;
    case 'Urgent':
      return 4;
    case 'DO NOW':
      return 5;
    default:
      // unset
      return 0;
  }
}
