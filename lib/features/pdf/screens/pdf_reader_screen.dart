/// The studio reader entry point.
///
/// The reader engine, its password flow and its native tile state machine stay
/// in `features/pdf/pdf_reader_screen.dart`. That file now renders the studio
/// chrome (dark top bar, page stepper, zoom controls and quick actions) around
/// the same viewport, so this path exists for the studio screens to import
/// without moving or forking the engine.
library;

export '../pdf_reader_screen.dart' show PdfReaderMode, PdfReaderScreen;
