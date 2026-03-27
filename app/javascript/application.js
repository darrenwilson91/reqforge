// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import * as Turbo from "@hotwired/turbo"
import "trix"
import "./controllers"

// Show the Turbo progress bar after a short delay (300ms)
// so quick navigations feel instant, but slow loads show feedback
Turbo.setProgressBarDelay(300)
