import LunchController from "./lunch_controller"
// import WorktimeController from "./worktime_controller"
import ChartController from "./chart_controller"
import AutosubmitController from "./autosubmit_controller"
import ProgressController from "./progress_controller"
import ReorderController from "./reorder_controller"
import OrderResetController from "./order_reset_controller"

// import WorktimeBusyController from "./worktime_busy_controller"


export default function registerControllers(app) {
  console.log("[app] registering controllers")
  app.register("chart", ChartController)
  app.register("lunch", LunchController)
  app.register("autosubmit", AutosubmitController)
  app.register("progress", ProgressController)
  app.register("reorder", ReorderController)
  app.register("orderreset", OrderResetController)
  // app.register("worktimebusy", WorktimeBusyController)
}
