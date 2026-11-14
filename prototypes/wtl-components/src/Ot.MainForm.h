#pragma once
#include "Ot.MainForm.Design.h"

namespace ot {
// Application form: named components + event handlers, no message map.
class TOtMainForm {
public:
    TOtMainForm();
    TOtMainForm(const TOtMainForm&) = delete;
    TOtMainForm& operator=(const TOtMainForm&) = delete;
    bool Create();
    void Show(int command);
private:
    TOtTaskController Controller;
    TOtFormWindow Window;
    TOtMainFormDesign FormDesign;
    bool ready_{};

    void BindEvents();
    bool FormCreate();
    void FormDestroy();
    void AddClick();
    void StartClick();
    void PauseClick();
    void RecheckClick();
    void RemoveClick();
    void AboutClick();
    void ExitClick();
    void AnimationClick();
    void DetailsClick();
    void AnimationTimer();
    void CategoryChange(TOtFilter filter);
    void ColumnClick(int column);
    void SelectionChange();
    void ApplyCommand(TOtTaskCommand command);
    void RefreshView();
};
}
