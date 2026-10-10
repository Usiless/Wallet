"""Offline Kotlin compilation and pure policy JUnit tests; never assembles an APK."""
from pathlib import Path
import glob
import subprocess
import tempfile

root = Path(__file__).resolve().parents[3]
cache = Path.home() / '.gradle/caches'
jars = glob.glob(str(cache / 'modules-2/files-2.1/**/*.jar'), recursive=True)
parts = ['/kotlin-compiler-embeddable/2.2.20/', '/kotlin-stdlib/2.2.20/',
         '/kotlin-reflect/1.6.10/', '/kotlin-script-runtime/2.2.20/', '/trove4j/',
         '/kotlinx-coroutines-core-jvm/', '/annotations/', '/junit/4.12/', '/hamcrest-core/']
compiler = ':'.join(p for p in jars if any(part in p for part in parts))
source = root / 'android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales'
test = root / 'android/app/src/test/kotlin/py/finanzaslocales/finanzas_locales/PaymentReminderReplacementTest.kt'


def compile_kotlin(classpath, output, files):
    subprocess.run(['java', '-cp', compiler, 'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler',
                    '-no-stdlib', '-no-reflect', '-classpath', classpath, '-d', str(output),
                    *map(str, files)], check=True)


with tempfile.TemporaryDirectory(prefix='cabal-reminder-check-') as temporary:
    output = Path(temporary)
    compile_kotlin(compiler, output / 'tests', [source / 'PaymentReminderReplacement.kt', test])
    subprocess.run(['java', '-cp', str(output / 'tests') + ':' + compiler,
                    'org.junit.runner.JUnitCore',
                    'py.finanzaslocales.finanzas_locales.PaymentReminderReplacementTest'], check=True)
    android_classpath = ':'.join([
        compiler, str(Path.home() / 'Android/Sdk/platforms/android-36/android.jar'),
        str(Path.home() / 'development/flutter/bin/cache/artifacts/engine/android-arm64/flutter.jar'),
        *glob.glob(str(cache / '9.1.0/transforms/**/jars/classes.jar'), recursive=True),
        *glob.glob(str(cache / 'modules-2/files-2.1/androidx.*/**/*.jar'), recursive=True),
    ])
    compile_kotlin(android_classpath, output / 'app', [*source.glob('*.kt'),
        root / 'build/app/generated/source/buildConfig/debug/py/finanzaslocales/finanzas_locales/BuildConfig.java'])
    print('All Kotlin app sources compile; 4 pure policy tests pass. No APK generated.')
