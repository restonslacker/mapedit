#' Interactively Edit a Map
#'
#' @param x map to edit
#'
#' @param ... other arguments
#'
#' @examples
#' library(leaflet)
#' library(mapedit)
#' edit_map(leaflet() %>% addTiles())
#'
#' @example inst/experiments/randgeo_edit.R
#' @export
edit_map <- function(x, ...) {
  UseMethod("edit_map")
}

#' @export
edit_map.leaflet <- function(x = NULL, targetLayerId = NULL) {
  stopifnot(!is.null(x), inherits(x, "leaflet"))

  stopifnot(
    requireNamespace("leaflet.extras"),
    requireNamespace("shiny"),
    requireNamespace("miniUI")
  )

  # check to see if addDrawToolbar has been already added to the map
  if(is.null(
    Find(
      function(cl) {
        cl$method == "addDrawToolbar"
      },
      x$x$calls
    )
  )) {
    # add draw toolbar if not found
    x <- leaflet.extras::addDrawToolbar(
      x,
      targetGroup = targetLayerId,
      editOptions = leaflet.extras::editToolbarOptions()
    )
  }

  ui <- miniUI::miniPage(
    miniUI::miniContentPanel(x, height=NULL, width=NULL),
    miniUI::gadgetTitleBar("Edit Map", right = miniUI::miniTitleBarButton("done", "Done", primary = TRUE))
  )

  server <- function(input, output, session) {
    drawn <- list()
    edited_all <- list()
    deleted_all <- list()
    finished <- drawn

    EVT_DRAW <- "undefined_draw_new_feature"
    EVT_EDIT <- "undefined_draw_edited_features"
    EVT_DELETE <- "undefined_draw_deleted_features"

    shiny::observeEvent(input[[EVT_DRAW]], {
      drawn <<- c(drawn, list(input[[EVT_DRAW]]))
      finished <<- c(finished, list(input[[EVT_DRAW]]))
    })

    shiny::observeEvent(input[[EVT_EDIT]], {
      edited <- input[[EVT_EDIT]]
      # find the edited features and update drawn
      # start by getting the leaflet ids to do the match
      ids <- unlist(lapply(finished, function(x){x$properties$`_leaflet_id`}))
      # now modify drawn to match edited
      lapply(edited$features, function(x) {
        loc <- match(x$properties$`_leaflet_id`, ids)
        if(length(loc) > 0) {
          finished[loc] <<- list(x)
        }
      })

      edited_all <<- c(edited_all, list(edited))
    })

    shiny::observeEvent(input[[EVT_DELETE]], {
      deleted <- input[[EVT_DELETE]]
      # find the deleted features and update finished
      # start by getting the leaflet ids to do the match
      ids <- unlist(lapply(finished, function(x){x$properties$`_leaflet_id`}))
      # now modify finished to match edited
      lapply(deleted$features, function(x) {
        loc <- match(x$properties$`_leaflet_id`, ids)
        if(length(loc) > 0) {
          finished[loc] <<- NULL
        }
      })

      deleted_all <<- c(deleted_all, list(deleted))
    })

    shiny::observeEvent(input$done, {
      shiny::stopApp(
        list(
          drawn = drawn,
          edited = edited_all,
          deleted = deleted_all,
          finished = finished
        )
      )
    })

    shiny::observeEvent(input$cancel, { shiny::stopApp (NULL) })
  }

  shiny::runGadget(
    ui,
    server,
    viewer =  shiny::dialogViewer("Draw and Edit"),
    stopOnCancel = FALSE
  )
}

