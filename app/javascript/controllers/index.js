import LunchController from "./lunch_controller"
// import WorktimeController from "./worktime_controller"
import ChartController from "./chart_controller"

export default function registerControllers(app) {
  app.register("chart", ChartController)
  app.register("lunch", LunchController)
}
