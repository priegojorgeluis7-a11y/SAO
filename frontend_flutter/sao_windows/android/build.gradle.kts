allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val rootBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(rootBuildDir)

subprojects {
    project.layout.buildDirectory.value(rootBuildDir.dir(project.name))
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
