allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }

    // Ensure Java compile settings for subprojects to avoid legacy Java 8 warnings
    tasks.withType<JavaCompile> {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
        // Add deprecation lint to help locate deprecated API usage in dependencies
        options.compilerArgs.add("-Xlint:deprecation")
        // Suppress obsolete-options warning if desired (optional):
        // options.compilerArgs.add("-Xlint:-options")
    }

    // Force an AndroidX compatibility artifact so legacy support library references are satisfied
    configurations.all {
        // This forces a common AndroidX replacement that often satisfies legacy support references
        resolutionStrategy.force("androidx.legacy:legacy-support-core-utils:1.0.0")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
