using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class UpdateFaceMaterialVector : MonoBehaviour
{
    [SerializeField] private Transform Head;
    [SerializeField] private Transform HeadForward;
    [SerializeField] private Transform HeadRight;
    [SerializeField] private Transform HeadUp;
    [SerializeField] private Material FaceMaterial;

    void Update()
    {
        Vector3 headForwardDir = Vector3.Normalize(HeadForward.position - Head.position);
        Vector3 headRightdDir = Vector3.Normalize(HeadRight.position - Head.position);
        Vector3 headUpdDir = Vector3.Normalize(HeadUp.position - Head.position);

        FaceMaterial.SetVector("_HeadForward",headForwardDir);
        FaceMaterial.SetVector("_HeadRight",headRightdDir);
        FaceMaterial.SetVector("_HeadUp",headUpdDir);
    }   
}
