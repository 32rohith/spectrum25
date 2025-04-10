enum Track {
  openInnovation('Open Innovation'),
  edtech('Edtech'),
  agriTechAndMedTech('AgriTech and MedTech'),
  blockchain('Blockchain'),
  iot('IoT'),
  sustainability('Sustainability & Social Well Being');

  final String displayName;
  const Track(this.displayName);

  static Track fromString(String value) {
    return Track.values.firstWhere(
      (track) => track.displayName.toLowerCase() == value.toLowerCase(),
      orElse: () => Track.openInnovation,
    );
  }
} 