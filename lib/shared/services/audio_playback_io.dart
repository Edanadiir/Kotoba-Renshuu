import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

AudioPlayer? _player;
StreamSubscription<PlayerState>? _stateSubscription;
StreamSubscription<PlayerException>? _errorSubscription;

AudioPlayer _getPlayer() {
  final existing = _player;
  if (existing != null) return existing;
  final player = AudioPlayer();
  _stateSubscription = player.playerStateStream.listen((state) {
    print(
      'AUDIO PLAYER EVENT: playing=${state.playing}, '
      'processing=${state.processingState.name}',
    );
  });
  _errorSubscription = player.errorStream.listen((error) {
    print('AUDIO PLAYER EVENT ERROR: ${error.message} (code=${error.code})');
  });
  _player = player;
  return player;
}

Future<void> playLocalAudio(String path) async {
  if (Platform.isWindows) {
    await _playWindowsFile(path);
    return;
  }
  final player = _getPlayer();
  await player.stop();
  await player.setVolume(1.0);
  await player.setFilePath(path);
  print('AUDIO PLAYER: Starting local playback: $path');
  await player.play();
}

Future<void> playRemoteAudio(String url) async {
  if (Platform.isWindows) {
    throw StateError('Windows audio must be downloaded before playback.');
  }
  final player = _getPlayer();
  await player.stop();
  await player.setVolume(1.0);
  await player.setUrl(url);
  print('AUDIO PLAYER: Starting URL playback: $url');
  await player.play();
}

Future<void> _playWindowsFile(String localPath) async {
  final file = File(localPath);
  final exists = file.existsSync();
  final length = exists ? file.lengthSync() : 0;
  print('AUDIO PLAYER WINDOWS: file=$localPath exists=$exists bytes=$length');
  if (!exists || length <= 0) {
    throw StateError('Windows audio file is missing or empty: $localPath');
  }

  const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
$path = $env:WANIKANI_AUDIO_PATH
if (-not (Test-Path -LiteralPath $path)) { throw "Audio file not found: $path" }

$player = New-Object System.Windows.Media.MediaPlayer
$player.Volume = 1.0
$script:mediaOpened = $false
$script:mediaFailed = $null
$player.add_MediaOpened({ $script:mediaOpened = $true })
$player.add_MediaFailed({
  param($sender, $eventArgs)
  $script:mediaFailed = $eventArgs.ErrorException.ToString()
})

function Invoke-DispatcherSlice {
  $frame = New-Object System.Windows.Threading.DispatcherFrame
  $timer = New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval = [TimeSpan]::FromMilliseconds(50)
  $timer.add_Tick({
    $this.Stop()
    $frame.Continue = $false
  })
  $timer.Start()
  [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

try {
  Write-Output "AUDIO PLAYER WINDOWS: Opening $path"
  $player.Open([System.Uri]::new($path))
  $openDeadline = [DateTime]::UtcNow.AddSeconds(20)
  while (-not $script:mediaOpened -and [DateTime]::UtcNow -lt $openDeadline) {
    if ($script:mediaFailed) { throw "MediaPlayer failed to open audio: $($script:mediaFailed)" }
    Invoke-DispatcherSlice
  }
  if (-not $script:mediaOpened) { throw 'MediaPlayer open timed out before MediaOpened.' }
  if (-not $player.NaturalDuration.HasTimeSpan) { throw 'MediaPlayer opened audio without a known duration.' }

  $duration = $player.NaturalDuration.TimeSpan
  if ($duration.TotalMilliseconds -le 0) { throw "Invalid audio duration: $duration" }
  Write-Output "AUDIO PLAYER WINDOWS: MediaOpened; duration=$duration"
  $player.Play()
  $playDeadline = [DateTime]::UtcNow.Add($duration).AddSeconds(10)
  while ($player.Position -lt $duration -and [DateTime]::UtcNow -lt $playDeadline) {
    if ($script:mediaFailed) { throw "MediaPlayer playback failed: $($script:mediaFailed)" }
    Invoke-DispatcherSlice
  }
  if ($player.Position -lt $duration) { throw 'MediaPlayer playback timed out before reaching the end.' }
  Write-Output 'AUDIO PLAYER WINDOWS: Playback completed.'
}
finally {
  $player.Stop()
  $player.Close()
}
''';

  print('AUDIO PLAYER WINDOWS: Starting WPF MediaPlayer playback...');
  final result = await Process.run(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-STA', '-Command', script],
    environment: {'WANIKANI_AUDIO_PATH': localPath},
    includeParentEnvironment: true,
  );
  if (result.stdout.toString().trim().isNotEmpty) {
    print('AUDIO PLAYER WINDOWS OUT: ${result.stdout}');
  }
  if (result.stderr.toString().trim().isNotEmpty) {
    print('AUDIO PLAYER WINDOWS STDERR: ${result.stderr}');
  }
  if (result.exitCode != 0) {
    throw ProcessException(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-STA', '-Command', script],
      '${result.stderr}${result.stdout}',
      result.exitCode,
    );
  }
  print('AUDIO PLAYER WINDOWS: Playback completed successfully.');
}

Future<void> disposeAudioPlayback() async {
  await _stateSubscription?.cancel();
  await _errorSubscription?.cancel();
  await _player?.dispose();
  _player = null;
}
