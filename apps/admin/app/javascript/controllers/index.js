import { application } from "./application"

const controllerFiles = import.meta.glob("./**/*_controller.js", { eager: true })

Object.entries(controllerFiles).forEach(([path, module]) => {
  const identifier = path
    .replace("./", "")
    .replace("_controller.js", "")
    .replace(/\//g, "--")
    .replace(/_/g, "-")

  application.register(identifier, module.default)
})
