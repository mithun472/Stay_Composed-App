/// Kept byte-for-byte in sync with `CAMPUS_LOCATIONS` in the backend's
/// `app/utils/locations.py`. Location is a fixed dropdown, not free text —
/// the backend rejects anything not in this list for a "found" report and
/// compares location strings exactly (case-insensitive) for match scoring,
/// so drifting from this list silently breaks matching.
class CampusLocations {
  CampusLocations._();

  static const String others = 'Others';

  static const List<String> all = [
    'New Block (NB)',
    'Physics UG & PG Block',
    'Chemistry UG & PG Block',
    'Rahda Thiagarajar Auditorium (RTA)',
    'Zoology Block (NH)',
    'Biotechnology Block',
    'Library Block',
    'TK Block',
    others,
  ];
}
