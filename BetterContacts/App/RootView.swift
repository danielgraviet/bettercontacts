import Domain
import SwiftUI

struct RootView: View {
    @State private var viewModel: ContactListViewModel

    init(environment: AppEnvironment) {
        _viewModel = State(
            initialValue: ContactListViewModel(
                repository: environment.repository,
                embedder: environment.embedder,
                calendar: environment.calendar,
                now: environment.now
            )
        )
    }

    var body: some View {
        NavigationStack {
            ContactListView(viewModel: viewModel)
        }
    }
}
