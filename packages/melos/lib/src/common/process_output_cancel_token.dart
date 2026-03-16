/// A token that can be used to cancel output logging for running processes.
///
/// Used to stop streaming output of dependent processes as soon as a failure
/// occurs (e.g. during a fail-fast operation).
///
/// `Process.killPid` (sigterm) allows for graceful process termination,
/// but packages can continue emitting logs during their shutdown phase. In
/// large repositories, these extra logs can quickly overflow terminal
/// buffers, pushing the actual failure reason out of reach. Using this token
/// allows processes to safely clean up their resources while instantly muting
/// any further noise.
class ProcessOutputCancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
