"""Regenerate the Xcode app target from the checked-in Swift sources/resources."""
from pathlib import Path
import hashlib
import plistlib

root = Path(__file__).resolve().parent.parent
objects = {}
def put(key, **obj):
    ident = hashlib.sha1(key.encode()).hexdigest()[:24].upper()
    objects[ident] = obj
    return ident

source_refs, source_builds = [], []
for path in sorted((root / 'Sources').rglob('*.swift')):
    rel = str(path.relative_to(root))
    ref = put('ref:' + rel, isa='PBXFileReference', lastKnownFileType='sourcecode.swift', path=rel, sourceTree='<group>')
    source_refs.append(ref)
    source_builds.append(put('build:' + rel, isa='PBXBuildFile', fileRef=ref))
children = []
for locale in ['en', 'zh-Hans', 'zh-Hant']:
    children.append(put('locale:' + locale, isa='PBXFileReference', lastKnownFileType='text.plist.strings', name=locale, path=f'Sources/Clipmio/Resources/{locale}.lproj/Localizable.strings', sourceTree='<group>'))
variant = put('strings', isa='PBXVariantGroup', children=children, name='Localizable.strings', sourceTree='<group>')
resource_refs = [variant]
resource_builds = [put('build:strings', isa='PBXBuildFile', fileRef=variant)]
for rel, kind in [('Sources/Clipmio/Resources/Acknowledgements.txt', 'text'), ('Assets/Clipmio.icns', 'image.icns'), ('Sources/Clipmio/Resources/ClipmioLogo.png', 'image.png')]:
    ref = put('ref:' + rel, isa='PBXFileReference', lastKnownFileType=kind, path=rel, sourceTree='<group>')
    resource_refs.append(ref)
    resource_builds.append(put('build:' + rel, isa='PBXBuildFile', fileRef=ref))
info = put('info', isa='PBXFileReference', lastKnownFileType='text.plist.xml', path='Configuration/Info.plist', sourceTree='<group>')
product = put('product', isa='PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='Clipmio.app', sourceTree='BUILT_PRODUCTS_DIR')
sources = put('sources', isa='PBXGroup', children=source_refs, name='Sources', sourceTree='<group>')
resources = put('resources', isa='PBXGroup', children=resource_refs, name='Resources', sourceTree='<group>')
products = put('products', isa='PBXGroup', children=[product], name='Products', sourceTree='<group>')
main = put('main', isa='PBXGroup', children=[sources, resources, info, products], sourceTree='<group>')
source_phase = put('source-phase', isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=source_builds, runOnlyForDeploymentPostprocessing=0)
resource_phase = put('resource-phase', isa='PBXResourcesBuildPhase', buildActionMask=2147483647, files=resource_builds, runOnlyForDeploymentPostprocessing=0)
framework_phase = put('framework-phase', isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
project_configs, target_configs = [], []
for config in ['Debug', 'Release']:
    common = {'MACOSX_DEPLOYMENT_TARGET': '14.0', 'SDKROOT': 'macosx', 'SWIFT_VERSION': '6.0', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if config == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if config == 'Debug' else 'dwarf-with-dsym', 'ENABLE_TESTABILITY': 'YES' if config == 'Debug' else 'NO', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG $(inherited)' if config == 'Debug' else '$(inherited)'}
    project_configs.append(put('project:' + config, isa='XCBuildConfiguration', buildSettings=common, name=config))
    settings = {'PRODUCT_NAME': 'Clipmio', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.tonngyou.clipmio.dev' if config == 'Debug' else 'com.tonngyou.clipmio', 'INFOPLIST_FILE': 'Configuration/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO', 'MARKETING_VERSION': '0.2.4', 'CURRENT_PROJECT_VERSION': '11', 'CODE_SIGN_IDENTITY': '-', 'CODE_SIGN_STYLE': 'Manual', 'ENABLE_HARDENED_RUNTIME': 'YES', 'ENABLE_APP_SANDBOX': 'NO', 'COMBINE_HIDPI_IMAGES': 'YES', 'SWIFT_EMIT_LOC_STRINGS': 'NO', 'SUPPORTED_PLATFORMS': 'macosx', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/../Frameworks'}
    target_configs.append(put('target:' + config, isa='XCBuildConfiguration', buildSettings=settings, name=config))
pc = put('project-configs', isa='XCConfigurationList', buildConfigurations=project_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
tc = put('target-configs', isa='XCConfigurationList', buildConfigurations=target_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
target = put('target', isa='PBXNativeTarget', buildConfigurationList=tc, buildPhases=[source_phase, framework_phase, resource_phase], buildRules=[], dependencies=[], name='Clipmio', productName='Clipmio', productReference=product, productType='com.apple.product-type.application')
proj = put('project', isa='PBXProject', attributes={'LastSwiftUpdateCheck': '1600', 'LastUpgradeCheck': '1600', 'TargetAttributes': {target: {'CreatedOnToolsVersion': '16.0', 'ProvisioningStyle': 'Manual'}}}, buildConfigurationList=pc, compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0, knownRegions=['en', 'Base', 'zh-Hans', 'zh-Hant'], mainGroup=main, productRefGroup=products, projectDirPath='', projectRoot='', targets=[target])
plist = {'archiveVersion': '1', 'classes': {}, 'objectVersion': '56', 'objects': objects, 'rootObject': proj}
(root / 'Clipmio.xcodeproj/project.pbxproj').write_bytes(plistlib.dumps(plist, sort_keys=False))
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Clipmio.app" BlueprintName="Clipmio" ReferencedContainer="container:Clipmio.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(root / 'Clipmio.xcodeproj/xcshareddata/xcschemes/Clipmio.xcscheme').write_text(scheme)
