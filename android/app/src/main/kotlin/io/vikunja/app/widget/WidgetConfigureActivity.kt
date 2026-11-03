package io.vikunja.app.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.SeekBar
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.core.net.toUri
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import io.vikunja.app.R

data class WidgetProject(val id: Int, val title: String)

class WidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var projects: List<WidgetProject> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.widget_configure)

        val prefs = HomeWidgetPlugin.getData(this)

        val projectsJson = prefs.getString("WidgetProjects", null)
        if (projectsJson != null) {
            try {
                val type = object : TypeToken<List<WidgetProject>>() {}.type
                val parsed: List<WidgetProject>? = Gson().fromJson(projectsJson, type)
                projects = parsed?.filterIsInstance<WidgetProject>() ?: emptyList()
            } catch (e: Exception) {
                projects = emptyList()
            }
        }

        val currentView = prefs.getString("widget_view_$appWidgetId", "today") ?: "today"
        val currentProjectId = prefs.getString("widget_project_id_$appWidgetId", "0")?.toIntOrNull() ?: 0
        val currentTheme = WidgetTheme.fromPref(prefs.getString("widget_theme_$appWidgetId", null))
        val currentOpacity = WidgetOpacity.fromPref(prefs.getString("widget_opacity_$appWidgetId", null))
        val currentDynamicColor =
            WidgetDynamicColor.fromPref(prefs.getString("widget_dynamic_color_$appWidgetId", null))

        val scrollView = findViewById<ScrollView>(R.id.scroll_view)
        val radioGroup = findViewById<RadioGroup>(R.id.view_radio_group)
        val themeRadioGroup = findViewById<RadioGroup>(R.id.theme_radio_group)
        val projectSpinner = findViewById<Spinner>(R.id.project_spinner)
        val projectLayout = findViewById<View>(R.id.project_layout)
        val saveButton = findViewById<Button>(R.id.save_button)
        val opacitySeekbar = findViewById<SeekBar>(R.id.opacity_seekbar)
        val opacityValue = findViewById<TextView>(R.id.opacity_value)
        val dynamicColorCheckbox = findViewById<CheckBox>(R.id.dynamic_color_checkbox)

        val projectNames = projects.map { it.title }
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, projectNames)
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        projectSpinner.adapter = adapter

        val radioProject = findViewById<RadioButton>(R.id.radio_project)
        radioProject.isEnabled = projects.isNotEmpty()

        when (currentView) {
            "inbox" -> radioGroup.check(R.id.radio_inbox)
            "upcoming" -> radioGroup.check(R.id.radio_upcoming)
            "project" -> {
                radioGroup.check(R.id.radio_project)
                projectLayout.visibility = View.VISIBLE
                val idx = projects.indexOfFirst { it.id == currentProjectId }
                if (idx >= 0) projectSpinner.setSelection(idx)
            }
            else -> radioGroup.check(R.id.radio_today)
        }

        when (currentTheme) {
            WidgetTheme.LIGHT -> themeRadioGroup.check(R.id.radio_theme_light)
            WidgetTheme.DARK -> themeRadioGroup.check(R.id.radio_theme_dark)
            WidgetTheme.AUTO -> themeRadioGroup.check(R.id.radio_theme_auto)
        }

        if (WidgetDynamicColors.isSupported()) {
            dynamicColorCheckbox.isChecked = currentDynamicColor
        } else {
            dynamicColorCheckbox.visibility = View.GONE
        }

        opacitySeekbar.progress = currentOpacity
        opacityValue.text = "$currentOpacity%"
        opacitySeekbar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                opacityValue.text = "$progress%"
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {}

            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        // Reset scroll to top after layout pass (prevents auto-scroll to checked radio)
        scrollView.post { scrollView.scrollTo(0, 0) }

        radioGroup.setOnCheckedChangeListener { _, checkedId ->
            projectLayout.visibility =
                if (checkedId == R.id.radio_project) View.VISIBLE else View.GONE
        }

        saveButton.setOnClickListener {
            val viewName = when (radioGroup.checkedRadioButtonId) {
                R.id.radio_inbox -> "inbox"
                R.id.radio_upcoming -> "upcoming"
                R.id.radio_project -> "project"
                else -> "today"
            }

            if (viewName == "project" && projects.isEmpty()) {
                Toast.makeText(
                    this,
                    "No projects available yet. Please try again in a moment.",
                    Toast.LENGTH_LONG,
                ).show()
                return@setOnClickListener
            }

            val selectedTheme = when (themeRadioGroup.checkedRadioButtonId) {
                R.id.radio_theme_light -> WidgetTheme.LIGHT
                R.id.radio_theme_dark -> WidgetTheme.DARK
                else -> WidgetTheme.AUTO
            }

            val editor = prefs.edit()
            editor.putString("widget_view_$appWidgetId", viewName)
            editor.putString("widget_theme_$appWidgetId", selectedTheme.prefName)
            editor.putString("widget_opacity_$appWidgetId", opacitySeekbar.progress.toString())
            editor.putString("widget_dynamic_color_$appWidgetId", dynamicColorCheckbox.isChecked.toString())

            if (viewName == "project") {
                val project = projects[projectSpinner.selectedItemPosition]
                editor.putString("widget_project_id_$appWidgetId", project.id.toString())
                editor.putString("widget_project_name_$appWidgetId", project.title)
            }

            val widgetIdsJson = prefs.getString("WidgetIds", "[]") ?: "[]"
            val listType = object : TypeToken<MutableList<String>>() {}.type
            val widgetIds: MutableList<String> =
                Gson().fromJson(widgetIdsJson, listType) ?: mutableListOf()
            if (!widgetIds.contains(appWidgetId.toString())) {
                widgetIds.add(appWidgetId.toString())
            }
            editor.putString("WidgetIds", Gson().toJson(widgetIds))
            editor.apply()

            val uri = "vikunja-app://updatewidget?widgetId=$appWidgetId".toUri()
            HomeWidgetBackgroundIntent.getBroadcast(this, uri).send()

            val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, result)
            finish()
        }
    }
}
