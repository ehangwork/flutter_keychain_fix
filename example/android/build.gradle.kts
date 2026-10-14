allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// `layout.buildDirectory.dir(...)` resolves relative to the build directory
// (android/build), not the project directory, so two levels up lands on the
// Flutter-standard `<project>/build` output folder.
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}