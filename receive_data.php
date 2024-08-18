<?php
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Directly accessing the POST array values without additional processing
    $peer_id = $_POST['peer_id'];
    $unclaimed_balance = $_POST['unclaimed_balance'];
    $quil_per_hour = $_POST['quil_per_hour'];

    // Debugging: Log raw POST data and interpreted values
    file_put_contents('raw_post_data.log', print_r($_POST, true), FILE_APPEND);
    file_put_contents('interpreted_data.log', "peer_id: $peer_id, unclaimed_balance: $unclaimed_balance, quil_per_hour: $quil_per_hour\n", FILE_APPEND);

    if ($peer_id && $unclaimed_balance && $quil_per_hour) {
        $timestamp = date("Y-m-d H:i:s"); // Get current timestamp
        file_put_contents('data.log', "$timestamp $peer_id $unclaimed_balance $quil_per_hour\n", FILE_APPEND);
        echo "Data received and logged.";
    } else {
        echo "Invalid data.";
    }
} else {
    echo "Invalid request method.";
}
