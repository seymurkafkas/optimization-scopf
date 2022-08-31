def process_line_and_bus_file(line_filename: str, bus_filename: str):
    BUS_FILE_FORMAT = [
        "bus_id",
        "bus_type",
        "bus_name",
        "bus_voltage",
        "bus_angle0",
        "bus_p_gen",
        "bus_q_gen",
        "bus_q_min",
        "bus_q_max",
        "bus_p_load",
        "bus_q_load",
        "bus_g_shunt",
        "bus_b_shunt",
        "bus_b_shunt_min",
        "bus_b_shunt_max",
        "bus_b_dispatch",
        "bus_area",
    ]

    LINE_FILE_FORMAT = [
        "line_id",
        "line_from",
        "line_to",
        "line_type ",
        "line_r",
        "line_x",
        "line_c",
        "line_tap",
        "line_tap_min",
        "line_tap_max",
        "line_def0",
        "line_def_min",
        "line_def_max",
    ]

    line_labeled_data = []
    bus_labeled_data = []
    slack_bus = None

    with open(line_filename) as line_file:
        for line in line_file:
            current_line = {}
            for index, word in enumerate(line.split()):
                current_line[LINE_FILE_FORMAT[index]] = word
            line_labeled_data.append(current_line)

    with open(bus_filename) as bus_file:
        for line in bus_file:
            current_bus = {}
            for index, word in enumerate(line.split()):
                current_bus[BUS_FILE_FORMAT[index]] = word
            bus_labeled_data.append(current_bus)

    for elem in bus_labeled_data:
        if elem["bus_type"] == "3":
            slack_bus = elem["bus_id"]

    return (slack_bus, line_labeled_data, bus_labeled_data)
