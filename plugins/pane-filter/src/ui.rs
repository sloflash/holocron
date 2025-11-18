use crate::state::{Mode, State};
use zellij_tile::prelude::*;

const CYAN: PaletteColor = PaletteColor::Cyan;
const GREEN: PaletteColor = PaletteColor::Green;
const RED: PaletteColor = PaletteColor::Red;
const ORANGE: PaletteColor = PaletteColor::Orange;
const WHITE: PaletteColor = PaletteColor::White;
const GRAY: PaletteColor = PaletteColor::Gray;

pub fn render(state: &State, rows: usize, cols: usize) {
    print_ribbon(state, cols);

    match state.mode {
        Mode::BrowsePanes => render_pane_list(state, rows, cols),
        Mode::SelectMethod => render_method_list(state, rows, cols),
        Mode::Confirm => render_confirmation(state, rows, cols),
    }

    print_status_line(state, rows, cols);
}

fn print_ribbon(state: &State, cols: usize) {
    let title = match state.mode {
        Mode::BrowsePanes => "PANE FILTER",
        Mode::SelectMethod => "SELECT METHOD",
        Mode::Confirm => "CONFIRM ACTION",
    };

    let help = match state.mode {
        Mode::BrowsePanes => "↑/↓: Navigate | Enter: Select | q: Quit",
        Mode::SelectMethod => "↑/↓: Navigate | Enter: Execute | Esc: Back",
        Mode::Confirm => "y: Confirm | n: Cancel",
    };

    print_text_with_coordinates(
        Text::new(format!("{:━<width$}", "", width = cols)),
        0,
        0,
        Some(cols),
        None,
    );

    print_text_with_coordinates(
        Text::new(format!(" {} ", title)).color_range(0, ..title.len() + 2),
        2,
        0,
        Some(title.len() + 4),
        None,
    );

    let help_x = cols.saturating_sub(help.len() + 4);
    print_text_with_coordinates(
        Text::new(format!(" {} ", help)).color_range(3, ..),
        help_x,
        0,
        Some(help.len() + 4),
        None,
    );
}

fn render_pane_list(state: &State, rows: usize, cols: usize) {
    let start_row = 2;
    let available_rows = rows.saturating_sub(4); // Leave space for header and footer

    if state.filtered_panes.is_empty() {
        let msg = if state.all_panes.is_empty() {
            "No panes found"
        } else {
            "No panes match the filters"
        };

        print_text_with_coordinates(
            Text::new(msg).color_range(2, ..),
            2,
            start_row + 2,
            Some(cols - 4),
            None,
        );

        if !state.config.pane_filters.is_empty() {
            print_text_with_coordinates(
                Text::new(format!("Active filters: {}", state.config.pane_filters.join(", ")))
                    .color_range(3, ..),
                2,
                start_row + 4,
                Some(cols - 4),
                None,
            );
        }
        return;
    }

    // Show filter info
    if !state.config.pane_filters.is_empty() {
        let filter_text = format!(
            "Filters: {} | Showing {}/{} panes",
            state.config.pane_filters.join(", "),
            state.filtered_panes.len(),
            state.all_panes.len()
        );
        print_text_with_coordinates(
            Text::new(filter_text).color_range(3, ..),
            2,
            start_row,
            Some(cols - 4),
            None,
        );
    }

    let list_start_row = start_row + if state.config.pane_filters.is_empty() { 0 } else { 2 };

    // Render pane list
    for (idx, pane) in state
        .filtered_panes
        .iter()
        .enumerate()
        .take(available_rows)
    {
        let row = list_start_row + idx;
        let is_selected = idx == state.selected_pane_index;

        let prefix = if is_selected { "▶ " } else { "  " };
        let focus_indicator = if pane.is_focused { "●" } else { "○" };
        let pane_type = if pane.is_plugin { "[PLUGIN]" } else { "[TERM]" };

        let line = format!(
            "{}{} {} {} - {}",
            prefix, focus_indicator, pane_type, pane.id, pane.title
        );

        let mut text = Text::new(line);
        if is_selected {
            text = text.color_range(0, ..);
        } else {
            text = text.color_range(3, ..);
        }

        print_text_with_coordinates(text, 2, row, Some(cols - 4), None);
    }
}

fn render_method_list(state: &State, rows: usize, cols: usize) {
    let start_row = 2;

    if let Some(pane) = state.get_selected_pane() {
        let info = format!("Selected pane: {} - {}", pane.id, pane.title);
        print_text_with_coordinates(
            Text::new(info).color_range(0, ..),
            2,
            start_row,
            Some(cols - 4),
            None,
        );
    }

    let list_start_row = start_row + 2;

    if state.methods.is_empty() {
        print_text_with_coordinates(
            Text::new("No methods configured").color_range(2, ..),
            2,
            list_start_row,
            Some(cols - 4),
            None,
        );

        if !state.config.methods_repo.is_empty() {
            print_text_with_coordinates(
                Text::new(format!("Methods repo: {}", state.config.methods_repo))
                    .color_range(3, ..),
                2,
                list_start_row + 2,
                Some(cols - 4),
                None,
            );
        }
        return;
    }

    print_text_with_coordinates(
        Text::new(format!("Available methods: {}", state.methods.len())).color_range(3, ..),
        2,
        list_start_row,
        Some(cols - 4),
        None,
    );

    let available_rows = rows.saturating_sub(list_start_row + 3);
    for (idx, method) in state
        .methods
        .iter()
        .enumerate()
        .take(available_rows / 2)
    {
        let row = list_start_row + 2 + (idx * 2);
        let is_selected = idx == state.selected_method_index;

        let prefix = if is_selected { "▶ " } else { "  " };
        let name_line = format!("{}{}", prefix, method.name);

        let mut name_text = Text::new(name_line);
        if is_selected {
            name_text = name_text.color_range(0, ..);
        } else {
            name_text = name_text.color_range(3, ..);
        }

        print_text_with_coordinates(name_text, 2, row, Some(cols - 4), None);

        // Description line
        let desc = if method.description.len() > cols - 8 {
            format!("{}...", &method.description[..cols - 11])
        } else {
            method.description.clone()
        };

        print_text_with_coordinates(
            Text::new(format!("    {}", desc)).color_range(3, ..),
            2,
            row + 1,
            Some(cols - 4),
            None,
        );
    }
}

fn render_confirmation(state: &State, rows: usize, cols: usize) {
    let start_row = rows / 2 - 3;

    if let (Some(pane), Some(method)) = (state.get_selected_pane(), state.get_selected_method()) {
        let messages = vec![
            "┌─ CONFIRM ACTION ─────────────────┐",
            "│                                  │",
            &format!("│ Execute: {}                    │", method.name)[..40.min(cols - 4)],
            &format!("│ On pane: {}                    │", pane.title)[..40.min(cols - 4)],
            "│                                  │",
            "│    Press 'y' to confirm          │",
            "│    Press 'n' to cancel           │",
            "│                                  │",
            "└──────────────────────────────────┘",
        ];

        for (idx, msg) in messages.iter().enumerate() {
            print_text_with_coordinates(
                Text::new(msg.to_string()).color_range(2, ..),
                (cols / 2).saturating_sub(20),
                start_row + idx,
                Some(40),
                None,
            );
        }
    }
}

fn print_status_line(state: &State, rows: usize, cols: usize) {
    let status_row = rows - 1;

    if let Some(ref message) = state.status_message {
        let status_text = if state.is_loading {
            format!("⟳ {}", message)
        } else {
            message.clone()
        };

        print_text_with_coordinates(
            Text::new(format!("{:━<width$}", "", width = cols)),
            0,
            status_row - 1,
            Some(cols),
            None,
        );

        print_text_with_coordinates(
            Text::new(format!(" {} ", status_text)).color_range(3, ..),
            2,
            status_row,
            Some(cols - 4),
            None,
        );
    }
}
